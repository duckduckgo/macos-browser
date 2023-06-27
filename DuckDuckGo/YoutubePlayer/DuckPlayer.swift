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

extension NSImage {
    static let duckPlayer: NSImage = #imageLiteral(resourceName: "DuckPlayer")
}

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

    static let duckPlayerHost: String = {
        if usesSimulatedRequests {
            return "www.youtube-nocookie.com"
        } else {
            return "player"
        }
    }()
    static let duckPlayerScheme = "duck"
    static let commonName = UserText.duckPlayer

    static let shared = DuckPlayer()

    var isAvailable: Bool {
        isFeatureEnabled
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

    public func handleSetUserValues(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let userValues: UserValues = DecodableHelper.decode(from: params) else {
            assertionFailure("YoutubeOverlayUserScript: expected JSON representation of UserValues")
            return nil
        }

        self.preferences.youtubeOverlayInteracted = userValues.overlayInteracted
        self.preferences.duckPlayerMode = userValues.duckPlayerMode

        return encodeUserValues()
    }

    public func handleGetUserValues(params: Any, message: UserScriptMessage) -> Encodable? {
        encodeUserValues()
    }

    private func encodeUserValues() -> UserValues {
        UserValues(
            duckPlayerMode: self.preferences.duckPlayerMode,
            overlayInteracted: self.preferences.youtubeOverlayInteracted
        )
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

    private func bindDuckPlayerModeIfNeeded() {
        if isFeatureEnabled {
            modeCancellable = preferences.$duckPlayerMode
                .removeDuplicates()
                .assign(to: \.mode, onWeaklyHeld: self)
        } else {
            modeCancellable = nil
        }
    }
}

// MARK: - Privacy Feed

extension DuckPlayer {

    func image(for faviconView: FaviconView) -> NSImage? {
        guard isAvailable, mode != .disabled, faviconView.domain == Self.commonName else {
            return nil
        }
        return .duckPlayer
    }

    func image(for bookmark: Bookmark) -> NSImage? {
        // Bookmarks to Duck Player pages retain duck:// URL even when Duck Player is disabled,
        // so we keep the Duck Player favicon even if Duck Player is currently disabled
        return (bookmark.urlObject?.isDuckPlayerScheme ?? false) ? .duckPlayer : nil
    }

    func domainForRecentlyVisitedSite(with url: URL) -> String? {
        guard isAvailable, mode != .disabled else {
            return nil
        }

        return url.isDuckPlayer ? DuckPlayer.commonName : nil
    }

    func sharingData(for title: String, url: URL) -> (title: String, url: URL)? {
        guard isAvailable, mode != .disabled, url.isDuckPlayerScheme, let (videoID, timestamp) = url.youtubeVideoParams else {
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

        guard page.url.isDuckPlayer || page.url.isDuckPlayerScheme else {
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
    var duckPlayerMode: DuckPlayerMode
    var youtubeOverlayInteracted: Bool

    init(duckPlayerMode: DuckPlayerMode = .alwaysAsk, youtubeOverlayInteracted: Bool = false) {
        self.duckPlayerMode = duckPlayerMode
        self.youtubeOverlayInteracted = youtubeOverlayInteracted
    }
}

extension DuckPlayer {

    static func mock(withMode mode: DuckPlayerMode = .enabled) -> DuckPlayer {
        let preferencesPersistor = DuckPlayerPreferencesPersistorMock(duckPlayerMode: mode, youtubeOverlayInteracted: true)
        let preferences = DuckPlayerPreferences(persistor: preferencesPersistor)
        // runtime mock-replacement for Unit Tests, to be redone when we‘ll be doing Dependency Injection
        let privacyConfigurationManager = ((NSClassFromString("MockPrivacyConfigurationManager") as? NSObject.Type)!.init() as? PrivacyConfigurationManaging)!
        return DuckPlayer(preferences: preferences, privacyConfigurationManager: privacyConfigurationManager)
    }

}

#else

extension DuckPlayer {
    static func mock(withMode mode: DuckPlayerMode = .enabled) -> DuckPlayer { fatalError() }
}

#endif
