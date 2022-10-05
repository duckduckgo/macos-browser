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

extension NSImage {
    static let privatePlayer: NSImage = #imageLiteral(resourceName: "PrivatePlayer")
}

enum PrivatePlayerMode: Equatable {
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
    static let privatePlayerHost = "www.youtube-nocookie.com"
    static let privatePlayerScheme = "privateplayer"
    static let commonName = UserText.privatePlayer

    static let shared = PrivatePlayer()

    @Published var mode: PrivatePlayerMode

    init(preferences: PrivatePlayerPreferences = .shared) {
        self.preferences = preferences
        mode = preferences.privatePlayerMode

        modeCancellable = preferences.$privatePlayerMode
            .removeDuplicates()
            .assign(to: \.mode, onWeaklyHeld: self)
    }

    func image(for faviconView: FaviconView) -> NSImage? {
        guard mode != .disabled, faviconView.domain == Self.commonName else {
            return nil
        }
        return .privatePlayer
    }

    func tabContent(for url: URL?) -> Tab.TabContent? {
        guard mode != .disabled, let url = url, let (videoID, timestamp) = url.youtubeVideoParams else {
            return nil
        }

        let shouldAlwaysOpenPrivatePlayer = url.isYoutubeVideo && mode == .enabled

        if url.isPrivatePlayerScheme || url.isPrivatePlayer || shouldAlwaysOpenPrivatePlayer {
            return .privatePlayer(videoID: videoID, timestamp: timestamp)
        }
        return nil
    }

    func shouldSkipLoadingURL(for tab: Tab) -> Bool {
        guard case .privatePlayer(let videoID, let timestamp) = tab.content,
           tab.webView.url == .youtubeNoCookie(videoID, timestamp: timestamp)
            || (tab.webView.url == .youtube(videoID, timestamp: timestamp) && mode != .enabled)
        else {
            return false
        }
        return true
    }

    func decidePolicy(for navigationAction: WKNavigationAction, in tab: Tab) -> WKNavigationActionPolicy? {
        guard mode != .disabled else {
            return nil
        }

        if navigationAction.request.url?.path == YoutubePlayerNavigationHandler.htmlTemplatePath {
            // don't allow loading Private Player HTML directly
            return .cancel
        }

        if navigationAction.request.url?.isPrivatePlayerScheme == true {
            return .allow
        }

        guard navigationAction.isTargetingMainFrame || tab.content.isPrivatePlayer, navigationAction.request.url?.isYoutubeVideo == true else {
            return nil
        }

        let alwaysOpenInPrivatePlayer = mode == .enabled
        let didSelectRecommendationFromPrivatePlayer = tab.content.isPrivatePlayer && navigationAction.request.url?.isYoutubeVideoRecommendation == true

        guard alwaysOpenInPrivatePlayer || didSelectRecommendationFromPrivatePlayer, let videoID = navigationAction.request.url?.youtubeVideoID else {
            return nil
        }

        if case .privatePlayer(let parentVideoID, _) = tab.parentTab?.content, parentVideoID == videoID {
            return nil
        }

        guard case .privatePlayer(let currentVideoID, _) = tab.content, currentVideoID == videoID, tab.webView.url?.isPrivatePlayer == true else {
            tab.webView.load(.privatePlayer(videoID))
            return .cancel
        }
        return nil
    }

    // MARK: - Private

    private static let websiteTitlePrefix = "\(commonName) - "
    private let preferences: PrivatePlayerPreferences
    private var modeCancellable: AnyCancellable?
}

// MARK: - Privacy Feed

extension PrivatePlayer {

    static func title(for page: HomePage.Models.RecentlyVisitedPageModel) -> String? {
        guard page.url.isPrivatePlayer, let actualTitle = page.actualTitle, actualTitle.starts(with: Self.websiteTitlePrefix) else {
            return nil
        }
        return actualTitle.dropping(prefix: Self.websiteTitlePrefix)
    }
}

// MARK: - Tab Content updating

extension PrivatePlayer {

    func updateContent(_ content: Tab.TabContent, for tab: Tab) -> Tab.TabContent? {
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
           tab.webView.url != .youtubeNoCookie(videoID, timestamp: timestamp) {

            return .url(.youtube(videoID))

        } else if let url = tab.webView.url, url.isYoutubeVideo == true {
            return .url(url)
        }
        return nil
    }
}
