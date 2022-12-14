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

import Foundation
import Combine
import WebKit
import BrowserServicesKit

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

// MARK: - Navigation

extension PrivatePlayer {

    func decidePolicy(for navigationAction: NavigationAction, in tab: Tab) -> NavigationActionPolicy? {
        guard isAvailable, mode != .disabled else {

            // When the feature is disabled but the webView still gets a Private Player URL,
            // convert it back to a regular YouTube video URL.
            if navigationAction.url.isPrivatePlayerScheme,
                let (videoID, timestamp) = navigationAction.url.youtubeVideoParams {

                tab.webView.load(.youtube(videoID, timestamp: timestamp))
                return .cancel
            }
            return nil
        }

        // Don't allow loading Private Player HTML directly
        if navigationAction.url.path == YoutubePlayerNavigationHandler.htmlTemplatePath {
            return .cancel
        }

        // Always allow loading Private Player URLs (local HTML)
        if navigationAction.url.isPrivatePlayerScheme {
            return .allow
        }

        // We only care about YouTube video URLs loaded into main frame or within a Private Player
        guard navigationAction.isForMainFrame || tab.content.isPrivatePlayer,
              navigationAction.url.isYoutubeVideo
        else {
            return nil
        }

        let alwaysOpenInPrivatePlayer = mode == .enabled

        // When Private Player is in enabled state (always open), and it's a back navigation from PP to a YouTube video page,
        // the PP would automatically load on that YouTube video, effectively cancelling the back navigation.
        // We need to go 2 sites back. That YouTube page wasn't really viewed by the user, but it was pushed on the
        // navigation stack and immediately replaced with Private Player. That's why skipping it while going back makes sense.
        if alwaysOpenInPrivatePlayer && isGoingBackFromPrivatePlayerToYoutubeVideo(for: navigationAction, in: tab) {
            tab.webView.goBack()
            return .cancel
        }

        let didSelectRecommendationFromPrivatePlayer = tab.content.isPrivatePlayer && navigationAction.url.isYoutubeVideoRecommendation

        // Recommendations must always be opened in Private Player.
        guard alwaysOpenInPrivatePlayer || didSelectRecommendationFromPrivatePlayer,
              let (videoID, timestamp) = navigationAction.url.youtubeVideoParams
        else {
            return nil
        }

        // If this is a child tab of a Private Player and it's loading a YouTube URL, don't override it ("Watch in YouTube").
        if case .privatePlayer(let parentVideoID, _) = tab.parentTab?.content, parentVideoID == videoID {
            return nil
        }

        // Otherwise load priate player unless it's already loaded.
        guard case .privatePlayer(let currentVideoID, _) = tab.content, currentVideoID == videoID, tab.webView.url?.isPrivatePlayer == true else {
            tab.webView.load(.privatePlayer(videoID, timestamp: timestamp))
            return .cancel
        }
        return nil
    }

    private func isGoingBackFromPrivatePlayerToYoutubeVideo(for navigationAction: NavigationAction, in tab: Tab) -> Bool {
        guard navigationAction.navigationType.isBackForward,
              let url = tab.webView.backForwardList.currentItem?.url,
              let forwardURL = tab.webView.backForwardList.forwardItem?.url
        else {
            return false
        }

        return url.isYoutubeVideo && forwardURL.isPrivatePlayer && url.youtubeVideoID == forwardURL.youtubeVideoID
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
        return bookmark.url.isPrivatePlayerScheme ? .privatePlayer : nil
    }

    func domainForRecentlyVisitedSite(with url: URL) -> String? {
        guard isAvailable, mode != .disabled else {
            return nil
        }

        return url.isPrivatePlayer ? PrivatePlayer.commonName : nil
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

// MARK: - Tab Content updating

extension PrivatePlayer {

    func tabContent(for url: URL?) -> Tab.TabContent? {
        guard isAvailable, mode != .disabled, let url = url, let (videoID, timestamp) = url.youtubeVideoParams else {
            return nil
        }

        // this will override regular YouTube video URL with a Private Player TabContent.
        let shouldAlwaysOpenPrivatePlayer = url.isYoutubeVideo && mode == .enabled

        if url.isPrivatePlayerScheme || url.isPrivatePlayer || shouldAlwaysOpenPrivatePlayer {
            return .privatePlayer(videoID: videoID, timestamp: timestamp)
        }
        return nil
    }

    func overrideContent(_ content: Tab.TabContent, for tab: Tab) -> Tab.TabContent? {
        guard isAvailable, mode != .disabled else {
            return nil
        }

        // If we're moving from Private Player to Private Player, sometimes it means we need to switch
        // back to a regular URL TabContent ("Watch in YouTube" or clicking video title in Private Player).
        let newContent: Tab.TabContent? = {
            if case .privatePlayer(let oldVideoID, _) = tab.content,
               case .privatePlayer(let videoID, let timestamp) = content,
               oldVideoID == videoID {

                return overrideTabContent(forOpeningYoutubeVideo: videoID, at: timestamp, fromPrivatePlayerTab: tab)
            }
            return nil
        }()
        if tab.content != newContent {
            return newContent
        }
        return nil
    }

    private func overrideTabContent(forOpeningYoutubeVideo videoID: String, at timestamp: String?, fromPrivatePlayerTab tab: Tab) -> Tab.TabContent? {
        if case .privatePlayer(let parentVideoID, _) = tab.parentTab?.content,
           parentVideoID == videoID,
           tab.webView.url != .effectivePrivatePlayer(videoID, timestamp: timestamp) {

            // Parent tab with the same videoID means it was a click on video title in Private Player.
            // Override with a YouTube URL.
            return .url(.youtube(videoID))

        } else if let url = tab.webView.url, url.isYoutubeVideo == true {

            // If a YouTube video URL is requested from Private Player, allow it.
            return .url(url)
        }
        return nil
    }
}

// MARK: - Private Player URL Loading

extension PrivatePlayer {

    func shouldSkipLoadingURL(for tab: Tab) -> Bool {
        guard isAvailable, mode != .disabled else {
            return false
        }

        // when in Private Player, don't reload if current URL is a Private Player target URL
        guard case .privatePlayer(let videoID, let timestamp) = tab.content,
              tab.webView.url == .effectivePrivatePlayer(videoID, timestamp: timestamp)
        else {
            return false
        }
        return true
    }

    func goBackAndLoadURLIfNeeded(for tab: Tab) -> Bool {
        guard isAvailable,
              mode != .disabled,
              tab.content.isPrivatePlayer,
              tab.webView.url?.isPrivatePlayer == true,
              tab.content.url?.youtubeVideoID == tab.webView.url?.youtubeVideoID,
              let url = tab.content.url
        else {
            return false
        }

        if tab.webView.canGoBack {
            _ = tab.webView.goBack()
        }
        tab.webView.load(url)

        return true
    }
}

// MARK: - Back navigation

extension PrivatePlayer {

    func goBackSkippingLastItemIfNeeded(for webView: WKWebView) -> Bool {
        guard isAvailable, mode == .enabled, webView.url?.isPrivatePlayer == true else {
            return false
        }

        let backList = webView.backForwardList.backList

        guard let backURL = webView.backForwardList.backItem?.url,
           backURL.isYoutubeVideo,
           backURL.youtubeVideoID == webView.url?.youtubeVideoID,
           let penultimateBackItem = backList[safe: backList.count - 2]
        else {
            return false
        }

        webView.go(to: penultimateBackItem)
        return true
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
