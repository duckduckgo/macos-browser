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
import WebKit

extension NSImage {
    static let privatePlayer: NSImage = #imageLiteral(resourceName: "PrivatePlayer")
}

struct PrivatePlayer {
    static let commonName = UserText.privatePlayer

    static var isDisabled: Bool {
        PrivacySecurityPreferences.shared.privateYoutubePlayerEnabled == false
    }

    static func image(for faviconView: FaviconView) -> NSImage? {
        guard !Self.isDisabled, faviconView.domain == Self.commonName else {
            return nil
        }
        return .privatePlayer
    }

    static func tabContent(for url: URL?) -> Tab.TabContent? {
        guard !Self.isDisabled, let url = url, let videoID = url.youtubeVideoID else {
            return nil
        }

        let shouldAlwaysOpenPrivatePlayer = url.isYoutubeVideo && PrivacySecurityPreferences.shared.privateYoutubePlayerEnabled == true

        if url.isPrivatePlayerScheme || url.isPrivatePlayer || shouldAlwaysOpenPrivatePlayer {
            return .privatePlayer(videoID: videoID)
        }
        return nil
    }

    static func overrideTabContentForChildTabIfNeeded(for tab: Tab) -> Tab.TabContent? {
        if tab.content == .none, case .privatePlayer(let parentVideoID) = tab.parentTab?.content, let url = tab.webView.url, url.isYoutubeVideo == true, url.youtubeVideoID == parentVideoID {
            return .url(url)
        }
        return nil
    }

    static func title(for page: HomePage.Models.RecentlyVisitedPageModel) -> String? {
        guard page.url.isPrivatePlayer, let actualTitle = page.actualTitle, actualTitle.starts(with: Self.websiteTitlePrefix) else {
            return nil
        }
        return actualTitle.dropping(prefix: Self.websiteTitlePrefix)
    }

    static func decidePolicy(for navigationAction: WKNavigationAction, in tab: Tab) -> WKNavigationActionPolicy? {
        guard !Self.isDisabled else {
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

        let alwaysOpenInPrivatePlayer = PrivacySecurityPreferences.shared.privateYoutubePlayerEnabled == true
        let didSelectRecommendationFromPrivatePlayer = tab.content.isPrivatePlayer && navigationAction.request.url?.isYoutubeVideoRecommendation == true

        guard alwaysOpenInPrivatePlayer || didSelectRecommendationFromPrivatePlayer, let videoID = navigationAction.request.url?.youtubeVideoID else {
            return nil
        }

        if case .privatePlayer(let parentVideoID) = tab.parentTab?.content, parentVideoID == videoID {
            return nil
        }

        guard case .privatePlayer(let currentVideoID) = tab.content, currentVideoID == videoID, tab.webView.url?.isPrivatePlayer == true else {
            tab.webView.load(.privatePlayer(videoID))
            return .cancel
        }
        return nil
    }

    // MARK: - Private

    private static let websiteTitlePrefix = "\(Self.commonName) - "
}

extension URL {
    static func privatePlayer(_ videoID: String) -> URL {
        "\(PrivatePlayerSchemeHandler.scheme):\(videoID)".url!
    }

    static func youtubeNoCookie(_ videoID: String) -> URL {
        "https://\(YoutubePlayerNavigationHandler.privatePlayerHost)/embed/\(videoID)?wmode=transparent&iv_load_policy=3&autoplay=1&html5=1&showinfo=0&rel=0&modestbranding=1&playsinline=0".url!
    }

    static func youtube(_ videoID: String) -> URL {
        "https://www.youtube.com/watch?v=\(videoID)".url!
    }

    var isPrivatePlayerScheme: Bool {
        scheme == PrivatePlayerSchemeHandler.scheme
    }

    var isPrivatePlayer: Bool {
        host == YoutubePlayerNavigationHandler.privatePlayerHost
    }

    /// Returns true only if the video represents a playlist itself, i.e. doesn't have `index` query parameter
    var isYoutubePlaylist: Bool {
        guard isYoutubeWatch, let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return false
        }

        let isPlaylistURL = components.queryItems?.contains(where: { $0.name == "list" }) == true &&
        components.queryItems?.contains(where: { $0.name == "index" }) == false

        return isPlaylistURL
    }

    var isYoutubeVideo: Bool {
        isYoutubeWatch && !isYoutubePlaylist
    }

    var isYoutubeVideoRecommendation: Bool {
        guard isYoutubeVideo,
              let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let featureQueryParameter = components.queryItems?.first(where: { $0.name == "feature" })?.value
        else {
            return false
        }

        let recommendationFeatures = [ "emb_rel_end", "emb_rel_pause" ]

        return recommendationFeatures.contains(featureQueryParameter)
    }

    private var isYoutubeWatch: Bool {
        host?.droppingWwwPrefix() == "youtube.com" && path == "/watch"
    }

    var youtubeVideoID: String? {
        let unsafeID: String? = {
            if isPrivatePlayerScheme {
                return absoluteString.split(separator: ":").last.flatMap(String.init)
            }

            if isPrivatePlayer {
                return lastPathComponent
            }

            guard isYoutubeVideo, let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
                return nil
            }
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }()
        return unsafeID?.removingCharacters(in: .youtubeVideoIDNotAllowed)
    }
}

private extension CharacterSet {
    static let youtubeVideoIDNotAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_").inverted
}
