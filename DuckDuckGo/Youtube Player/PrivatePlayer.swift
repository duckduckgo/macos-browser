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

    static func title(for page: HomePage.Models.RecentlyVisitedPageModel) -> String? {
        guard page.url.isPrivatePlayer, let actualTitle = page.actualTitle, actualTitle.starts(with: Self.websiteTitlePrefix) else {
            return nil
        }
        return actualTitle.dropping(prefix: Self.websiteTitlePrefix)
    }

    static func decidePolicy(for navigationAction: WKNavigationAction, in tab: Tab) -> WKNavigationActionPolicy? {
        guard PrivacySecurityPreferences.shared.privateYoutubePlayerEnabled != false else {
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
