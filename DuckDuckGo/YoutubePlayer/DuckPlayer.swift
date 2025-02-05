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
import NewTabPage
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
struct InitialPlayerSettings: Codable {
    struct PlayerSettings: Codable {
        let pip: PIP
        let autoplay: Autoplay
        let focusMode: FocusMode
    }

    struct PIP: Codable {
        let state: State
    }

    struct Platform: Codable {
        let name: String
    }

    enum Locale: String, Codable {
        case en
    }

    struct Autoplay: Codable {
        let state: State
    }

    /// Represents the current focus mode of the player.
    ///
    /// Focus mode determines whether the bottom toolbar should be visible or hidden.
    /// When focus mode is enabled, the toolbar will auto-hide after a few seconds.
    /// When focus mode is disabled, the toolbar will always be visible and the background wallpaper will be slightly brighter.
    ///
    /// Default should be enabled.
    struct FocusMode: Codable {
        let state: State
    }

    enum State: String, Codable {
        case enabled
        case disabled
    }

    enum Environment: String, Codable {
        case development
        case production
    }

    let userValues: UserValues
    let settings: PlayerSettings
    let platform: Platform
    let environment: Environment
    let locale: Locale

}

struct InitialOverlaySettings: Codable {
    let userValues: UserValues
    let ui: UIUserValues
}

// Values that the YouTube Overlays can use to determine the current state
struct OverlaysInitialSettings: Codable {
    let userValues: UserValues
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

public struct UIUserValues: Codable {
    /// If this value is true, we force the FE layer to play in duck player even if the settings is off
    let playInDuckPlayer: Bool
    let allowFirstVideo: Bool

    init(onboardingDecider: DuckPlayerOnboardingDecider, allowFirstVideo: Bool = false) {
        self.playInDuckPlayer = onboardingDecider.shouldOpenFirstVideoOnDuckPlayer
        self.allowFirstVideo = allowFirstVideo
    }
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

    var shouldDisplayPreferencesSideBar: Bool {
        isAvailable || preferences.shouldDisplayContingencyMessage
    }

    init(
        preferences: DuckPlayerPreferences = .shared,
        privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
        onboardingDecider: DuckPlayerOnboardingDecider = DefaultDuckPlayerOnboardingDecider()
    ) {
        self.preferences = preferences
        isFeatureEnabled = privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .duckPlayer)
        isPiPFeatureEnabled = privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DuckPlayerSubfeature.pip)
        isAutoplayFeatureEnabled = privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DuckPlayerSubfeature.autoplay)
        self.onboardingDecider = onboardingDecider

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
                // flag that plays a role here). We want to anonymously track users opting in to not showing overlays,
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

    public func initialPlayerSetup(with webView: WKWebView?) -> (_ params: Any, _ message: UserScriptMessage) async -> Encodable? {
        return { _, _ in
            return await self.encodedPlayerSettings(with: webView)
        }
    }

    public func initialOverlaySetup(with webView: WKWebView?) -> (_ params: Any, _ message: UserScriptMessage) async -> Encodable? {
        return { _, _ in
            return await self.encodedOverlaySettings(with: webView)
        }
    }

    private func encodeUserValues() -> UserValues {
        UserValues(
            duckPlayerMode: self.preferences.duckPlayerMode,
            overlayInteracted: self.preferences.youtubeOverlayInteracted
        )
    }

    @MainActor
    private func encodedPlayerSettings(with webView: WKWebView?) async -> InitialPlayerSettings {
        var isPiPEnabled = webView?.configuration.preferences[.allowsPictureInPictureMediaPlayback] == true

        var isAutoplayEnabled = DuckPlayerPreferences.shared.duckPlayerAutoplay

        /// If the feature flag is disabled, we want to turn autoPlay to false
        /// https://app.asana.com/0/1204167627774280/1207906550241281/f
        if !isAutoplayFeatureEnabled {
            isAutoplayEnabled = false
        }

        // Disable WebView PiP if if the subFeature is off
        if !isPiPFeatureEnabled {
            webView?.configuration.preferences[.allowsPictureInPictureMediaPlayback] = false
            isPiPEnabled = false
        }

        let pip = InitialPlayerSettings.PIP(state: isPiPEnabled ? .enabled : .disabled)
        let autoplay = InitialPlayerSettings.Autoplay(state: isAutoplayEnabled ? .enabled : .disabled)
        let platform = InitialPlayerSettings.Platform(name: "macos")
        let environment = InitialPlayerSettings.Environment.development
        let locale = InitialPlayerSettings.Locale.en
        let focusMode = InitialPlayerSettings.FocusMode(state: onboardingDecider.shouldOpenFirstVideoOnDuckPlayer ? .disabled : .enabled)
        let playerSettings = InitialPlayerSettings.PlayerSettings(pip: pip, autoplay: autoplay, focusMode: focusMode)
        let userValues = encodeUserValues()

        /// Since the FE is requesting player-encoded values, we can assume that the first player video setup is complete from the onboarding point of view.
        onboardingDecider.setFirstVideoInDuckPlayerAsDone()

        return InitialPlayerSettings(userValues: userValues,
                                     settings: playerSettings,
                                     platform: platform,
                                     environment: environment,
                                     locale: locale)
    }

    @MainActor
    private func encodedOverlaySettings(with webView: WKWebView?) async -> InitialOverlaySettings {
        let userValues = encodeUserValues()

        /// If the user clicked on "Watch on Youtube" the next vide should open directly on youtube instead of displaying the overlay
        let allowFirstVideo = shouldOpenNextVideoOnYoutube

        /// Reset the flag for subsequent videos
        shouldOpenNextVideoOnYoutube = false
        return InitialOverlaySettings(userValues: userValues,
                                      ui: UIUserValues(onboardingDecider: onboardingDecider,
                                                       allowFirstVideo: allowFirstVideo))
    }

    public func setNextVideoToOpenOnYoutube() {
        self.shouldOpenNextVideoOnYoutube = true
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
    private var isAutoplayFeatureEnabled: Bool
    private let onboardingDecider: DuckPlayerOnboardingDecider
    private var shouldOpenNextVideoOnYoutube: Bool = false

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
        title(forHistoryItemWithTitle: page.actualTitle, url: page.url)
    }

    func title(for historyEntry: NewTabPageDataModel.HistoryEntry) -> String? {
        title(forHistoryItemWithTitle: historyEntry.title, url: historyEntry.url.url)
    }

    func title(forHistoryItemWithTitle title: String?, url: URL?) -> String? {
        guard isAvailable, mode != .disabled, let url else {
            return nil
        }

        guard url.isDuckPlayer else {
            return nil
        }

        // Private Player page titles are "Duck Player - <YouTube video title>".
        // Extract YouTube video title or fall back to the video ID.
        guard let title, title.starts(with: Self.websiteTitlePrefix) else {
            return url.youtubeVideoID
        }
        return title.dropping(prefix: Self.websiteTitlePrefix)
    }
}

#if DEBUG

final class DuckPlayerPreferencesPersistorMock: DuckPlayerPreferencesPersistor {
    var duckPlayerModeBool: Bool?
    var youtubeOverlayInteracted: Bool
    var youtubeOverlayAnyButtonPressed: Bool
    var duckPlayerAutoplay: Bool
    var duckPlayerOpenInNewTab: Bool

    init(duckPlayerMode: DuckPlayerMode = .alwaysAsk,
         youtubeOverlayInteracted: Bool = false,
         youtubeOverlayAnyButtonPressed: Bool = false,
         duckPlayerAutoplay: Bool = false,
         duckPlayerOpenInNewTab: Bool = false) {
        self.duckPlayerModeBool = duckPlayerMode.boolValue
        self.youtubeOverlayInteracted = youtubeOverlayInteracted
        self.youtubeOverlayAnyButtonPressed = youtubeOverlayAnyButtonPressed
        self.duckPlayerAutoplay = duckPlayerAutoplay
        self.duckPlayerOpenInNewTab = duckPlayerOpenInNewTab
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
