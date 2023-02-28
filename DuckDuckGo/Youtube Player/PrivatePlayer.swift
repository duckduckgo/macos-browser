//
//  PrivatePlayer.swift
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
import Combine
import Foundation
import Navigation
import WebKit

extension NSImage {
    static let privatePlayer: NSImage = #imageLiteral(resourceName: "PrivatePlayer")
}

enum PrivatePlayerMode: Equatable, Codable {
    case enabled, alwaysAsk, disabled

    init(_ privatePlayerMode: Bool?) {
        switch privatePlayerMode {
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

final class PrivatePlayer {
    static let usesSimulatedRequests: Bool = {
        if #available(macOS 12.0, *) {
            return true
        } else {
            return false
        }
    }()

    static let privatePlayerHost: String = {
        if usesSimulatedRequests {
            return "www.youtube-nocookie.com"
        } else {
            return "player"
        }
    }()
    static let privatePlayerScheme = "duck"
    static let commonName = UserText.privatePlayer

    static let shared = PrivatePlayer()

    var isAvailable: Bool {
        isFeatureEnabled
    }

    @Published var mode: PrivatePlayerMode

    var overlayInteracted: Bool {
        preferences.youtubeOverlayInteracted
    }

    init(
        preferences: PrivatePlayerPreferences = .shared,
        privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager
    ) {
        self.preferences = preferences
        isFeatureEnabled = privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .duckPlayer)
        mode = preferences.privatePlayerMode
        bindPrivatePlayerModeIfNeeded()

        isFeatureEnabledCancellable = privacyConfigurationManager.updatesPublisher
            .map { [weak privacyConfigurationManager] in
                privacyConfigurationManager?.privacyConfig.isEnabled(featureKey: .duckPlayer) == true
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isFeatureEnabled, onWeaklyHeld: self)
    }

    // MARK: - Private

    private static let websiteTitlePrefix = "\(commonName) - "
    private let preferences: PrivatePlayerPreferences

    private var isFeatureEnabled: Bool = false {
        didSet {
            bindPrivatePlayerModeIfNeeded()
        }
    }
    private var modeCancellable: AnyCancellable?
    private var isFeatureEnabledCancellable: AnyCancellable?

    private func bindPrivatePlayerModeIfNeeded() {
        if isFeatureEnabled {
            modeCancellable = preferences.$privatePlayerMode
                .removeDuplicates()
                .assign(to: \.mode, onWeaklyHeld: self)
        } else {
            modeCancellable = nil
        }
    }
}

// MARK: - Privacy Feed

extension PrivatePlayer {

    func image(for faviconView: FaviconView) -> NSImage? {
        guard isAvailable, mode != .disabled, faviconView.domain == Self.commonName else {
            return nil
        }
        return .privatePlayer
    }

    func image(for bookmark: Bookmark) -> NSImage? {
        // Bookmarks to Duck Player pages retain duck:// URL even when Duck Player is disabled,
        // so we keep the Duck Player favicon even if Duck Player is currently disabled
        return (bookmark.urlObject?.isPrivatePlayerScheme ?? false) ? .privatePlayer : nil
    }

    func domainForRecentlyVisitedSite(with url: URL) -> String? {
        guard isAvailable, mode != .disabled else {
            return nil
        }

        return url.isPrivatePlayer ? PrivatePlayer.commonName : nil
    }

    func sharingData(for title: String, url: URL) -> (title: String, url: URL)? {
        guard isAvailable, mode != .disabled, url.isPrivatePlayerScheme, let (videoID, timestamp) = url.youtubeVideoParams else {
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

        guard page.url.isPrivatePlayer || page.url.isPrivatePlayerScheme else {
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

final class PrivatePlayerPreferencesPersistorMock: PrivatePlayerPreferencesPersistor {
    var privatePlayerMode: PrivatePlayerMode
    var youtubeOverlayInteracted: Bool

    init(privatePlayerMode: PrivatePlayerMode = .alwaysAsk, youtubeOverlayInteracted: Bool = false) {
        self.privatePlayerMode = privatePlayerMode
        self.youtubeOverlayInteracted = youtubeOverlayInteracted
    }
}

extension PrivatePlayer {

    static func mock(withMode mode: PrivatePlayerMode = .enabled) -> PrivatePlayer {
        let preferencesPersistor = PrivatePlayerPreferencesPersistorMock(privatePlayerMode: mode, youtubeOverlayInteracted: true)
        let preferences = PrivatePlayerPreferences(persistor: preferencesPersistor)
        // runtime mock-replacement for Unit Tests, to be redone when we‘ll be doing Dependency Injection
        let privacyConfigurationManager = ((NSClassFromString("MockPrivacyConfigurationManager") as? NSObject.Type)!.init() as? PrivacyConfigurationManaging)!
        return PrivatePlayer(preferences: preferences, privacyConfigurationManager: privacyConfigurationManager)
    }

}

#else

extension PrivatePlayer {
    static func mock(withMode mode: PrivatePlayerMode = .enabled) -> PrivatePlayer { fatalError() }
}

#endif
