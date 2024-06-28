//
//  DuckPlayer.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import BrowserServicesKit
import Common
import Combine
import Foundation
import Navigation
import WebKit
import UserScript
import PixelKit

enum DuckPlayerMode: Equatable, Codable {
    case enabled, alwaysAsk, disabled

    init(_ duckPlayerMode: Bool?) {
        switch duckPlayerMode {
        case true:
            self = .enabled
        case false:
            self = .disabled
        default:
            self = .alwaysAsk
        }
    }

    var boolValue: Bool? {
        switch self {
        case .enabled:
            return true
        case .alwaysAsk:
            return nil
        case .disabled:
            return false
        }
    }

}

/// Values that the Frontend can use to determine the current state.
struct InitialSetupSettings: Codable {
    struct PlayerSettings: Codable {
        let pip: PIP
        let autoplay: Autoplay
    }

    struct PIP: Codable {
        let state: State
    }

    struct Autoplay: Codable {
        let state: State
    }

    enum State: String, Codable {
        case enabled
        case disabled
    }

    let userValues: UserValues
    let settings: PlayerSettings
}

/// Values that the Frontend can use to determine user settings
public struct UserValues: Codable {
    enum CodingKeys: String, CodingKey {
        case duckPlayerMode = "privatePlayerMode"
        case overlayInteracted
    }
    let duckPlayerMode: DuckPlayerMode
    let overlayInteracted: Bool
}

final class DuckPlayer {
    static let usesSimulatedRequests: Bool = {
        if #available(macOS 12.0, *) {
            return true
        } else {
            return false
        }
    }()

    static let duckPlayerHost: String = "player"
    static let commonName = UserText.duckPlayer

    static let shared = DuckPlayer()

    var isAvailable: Bool {
        if SupportedOSChecker.isCurrentOSReceivingUpdates {
            return isFeatureEnabled
        } else {
            return false
        }
    }

    @Published var mode: DuckPlayerMode

    var overlayInteracted: Bool {
        preferences.youtubeOverlayInteracted
    }

    init(
        preferences: DuckPlayerPreferences = .shared,
        privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager
    ) {
        self.preferences = preferences
        isFeatureEnabled = privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .duckPlayer)
        isPiPFeatureEnabled = privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DuckPlayerSubfeature.pip)

#warning("Change the subfeature once BSK is done")
        isAutoplayEnabled = privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DuckPlayerSubfeature.pip)

        mode = preferences.duckPlayerMode
        bindDuckPlayerModeIfNeeded()

        isFeatureEnabledCancellable = privacyConfigurationManager.updatesPublisher
            .map { [weak privacyConfigurationManager] in
                privacyConfigurationManager?.privacyConfig.isEnabled(featureKey: .duckPlayer) == true
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isFeatureEnabled, onWeaklyHeld: self)
    }

    // MARK: - Common Message Handlers

    // swiftlint:disable:next cyclomatic_complexity
    public func handleSetUserValuesMessage(
        from origin: YoutubeOverlayUserScript.MessageOrigin
    ) -> (_ params: Any, _ message: UserScriptMessage) -> Encodable? {

        return { [weak self] params, _ -> Encodable? in
            guard let self else {
                return nil
            }
            guard let userValues: UserValues = DecodableHelper.decode(from: params) else {
                assertionFailure("YoutubeOverlayUserScript: expected JSON representation of UserValues")
                return nil
            }

            let modeDidChange = self.preferences.duckPlayerMode != userValues.duckPlayerMode
            let overlayDidInteract = !self.preferences.youtubeOverlayInteracted && userValues.overlayInteracted

            if modeDidChange {
                self.preferences.duckPlayerMode = userValues.duckPlayerMode
                if case .enabled = userValues.duckPlayerMode {
                    switch origin {
                    case .duckPlayer:
                        PixelKit.fire(GeneralPixel.duckPlayerSettingAlwaysDuckPlayer)
                    case .serpOverlay:
                        PixelKit.fire(GeneralPixel.duckPlayerSettingAlwaysOverlaySERP)
                    case .youtubeOverlay:
                        PixelKit.fire(GeneralPixel.duckPlayerSettingAlwaysOverlayYoutube)
                    }
                }
            }

            if overlayDidInteract {
                self.preferences.youtubeOverlayInteracted = userValues.overlayInteracted

                // If user checks "Remember my choice" and clicks "Watch here", we won't show
                // the overlay anymore, but will keep presenting Dax logos (the mode stays at
                // "alwaysAsk" which may be a bit counterintuitive, but it's the overlayInteracted
                // flag that plays a role here). We want to track users opting in to not showing overlays,
                // hence firing the pixel here.
                if userValues.duckPlayerMode == .alwaysAsk {
                    switch origin {
                    case .serpOverlay:
                        PixelKit.fire(GeneralPixel.duckPlayerSettingNeverOverlaySERP)
                    case .youtubeOverlay:
                        PixelKit.fire(GeneralPixel.duckPlayerSettingNeverOverlayYoutube)
                    default:
                        break
                    }
                }
            }

            return self.encodeUserValues()
        }
    }

    public func handleGetUserValues(params: Any, message: UserScriptMessage) -> Encodable? {
        encodeUserValues()
    }

    public func initialSetup(with webView: WKWebView?) -> (_ params: Any, _ message: UserScriptMessage) async -> Encodable? {
        return { _, _ in
            return await self.encodedSettings(with: webView)
        }
    }

    private func encodeUserValues() -> UserValues {
        UserValues(
            duckPlayerMode: self.preferences.duckPlayerMode,
            overlayInteracted: self.preferences.youtubeOverlayInteracted
        )
    }

    @MainActor
    private func encodedSettings(with webView: WKWebView?) async -> InitialSetupSettings {
        var isPiPEnabled = webView?.configuration.preferences[.allowsPictureInPictureMediaPlayback] == true

        // Disable WebView PiP if if the subFeature is off
        if !isPiPFeatureEnabled {
            webView?.configuration.preferences[.allowsPictureInPictureMediaPlayback] = false
            isPiPEnabled = false
        }

        let pip = InitialSetupSettings.PIP(state: isPiPEnabled ? .enabled : .disabled)
        let autoplay = InitialSetupSettings.Autoplay(state: isAutoplayEnabled ? .enabled : .disabled)

        let playerSettings = InitialSetupSettings.PlayerSettings(pip: pip, autoplay: autoplay)
        let userValues = encodeUserValues()

        return InitialSetupSettings(userValues: userValues, settings: playerSettings)
    }

    // MARK: - Private

    private static let websiteTitlePrefix = "\(commonName) - "
    private let preferences: DuckPlayerPreferences

    private var isFeatureEnabled: Bool = false {
        didSet {
            bindDuckPlayerModeIfNeeded()
        }
    }
    private var modeCancellable: AnyCancellable?
    private var isFeatureEnabledCancellable: AnyCancellable?
    private var isPiPFeatureEnabled: Bool
    private var isAutoplayEnabled: Bool

    private func bindDuckPlayerModeIfNeeded() {
        if isFeatureEnabled {
            modeCancellable = preferences.$duckPlayerMode
                .removeDuplicates()
                .dropFirst(1)
                .prepend(preferences.duckPlayerMode)
                .assign(to: \.mode, onWeaklyHeld: self)
        } else {
            modeCancellable = nil
        }
    }
}

// MARK: - Privacy Feed

extension DuckPlayer {

    func image(for faviconView: FaviconView) -> NSImage? {
        guard isAvailable, mode != .disabled, faviconView.url?.isDuckPlayer == true else {
            return nil
        }
        return .duckPlayer
    }

    func image(for bookmark: Bookmark) -> NSImage? {
        // Bookmarks to Duck Player pages retain duck:// URL even when Duck Player is disabled,
        // so we keep the Duck Player favicon even if Duck Player is currently disabled
        return (bookmark.urlObject?.isDuckPlayer ?? false) ? .duckPlayer : nil
    }

    func domainForRecentlyVisitedSite(with url: URL) -> String? {
        guard isAvailable, mode != .disabled else {
            return nil
        }

        return url.isDuckPlayer ? DuckPlayer.commonName : nil
    }

    func sharingData(for title: String, url: URL) -> (title: String, url: URL)? {
        guard isAvailable, mode != .disabled, url.isDuckURLScheme, let (videoID, timestamp) = url.youtubeVideoParams else {
            return nil
        }

        let title = title.dropping(prefix: Self.websiteTitlePrefix)
        let sharingURL = URL.youtube(videoID, timestamp: timestamp)

        return (title, sharingURL)
    }

    func title(for page: HomePage.Models.RecentlyVisitedPageModel) -> String? {
        guard isAvailable, mode != .disabled else {
            return nil
        }

        guard page.url.isDuckPlayer else {
            return nil
        }

        // Private Player page titles are "Duck Player - <YouTube video title>".
        // Extract YouTube video title or fall back to the video ID.
        guard let actualTitle = page.actualTitle, actualTitle.starts(with: Self.websiteTitlePrefix) else {
            return page.url.youtubeVideoID
        }
        return actualTitle.dropping(prefix: Self.websiteTitlePrefix)
    }

}

#if DEBUG

final class DuckPlayerPreferencesPersistorMock: DuckPlayerPreferencesPersistor {
    var duckPlayerModeBool: Bool?
    var youtubeOverlayInteracted: Bool
    var youtubeOverlayAnyButtonPressed: Bool
    var duckPlayerAutoplay: Bool

    init(duckPlayerMode: DuckPlayerMode = .alwaysAsk,
         youtubeOverlayInteracted: Bool = false,
         youtubeOverlayAnyButtonPressed: Bool = false,
         duckPlayerAutoplay: Bool = false) {
        self.duckPlayerModeBool = duckPlayerMode.boolValue
        self.youtubeOverlayInteracted = youtubeOverlayInteracted
        self.youtubeOverlayAnyButtonPressed = youtubeOverlayAnyButtonPressed
        self.duckPlayerAutoplay = duckPlayerAutoplay
    }
}

extension DuckPlayer {

    static func mock(withMode mode: DuckPlayerMode = .enabled) -> DuckPlayer {
        let preferencesPersistor = DuckPlayerPreferencesPersistorMock(duckPlayerMode: mode, youtubeOverlayInteracted: true)
        let preferences = DuckPlayerPreferences(persistor: preferencesPersistor)
        // runtime mock-replacement for Unit Tests, to be redone when we‘ll be doing Dependency Injection
        let privacyConfigurationManager = MockPrivacyConfigurationManager()
        return DuckPlayer(preferences: preferences, privacyConfigurationManager: privacyConfigurationManager)
    }

}

#else

extension DuckPlayer {
    static func mock(withMode mode: DuckPlayerMode = .enabled) -> DuckPlayer { fatalError() }
}

#endif
