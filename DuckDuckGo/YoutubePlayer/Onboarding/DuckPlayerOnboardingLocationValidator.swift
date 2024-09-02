//
//  DuckPlayerOnboardingLocationValidator.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Navigation

struct DuckPlayerOnboardingLocationValidator {
    private static let youtubeChannelCheckScript = """
        (function() {
            var canonicalLink = document.querySelector('link[rel="canonical"]');
            return canonicalLink && canonicalLink.href.includes('channel');
        })();
    """

    func isValidLocation(_ webView: WKWebView) async -> Bool {
        guard let url = await webView.url,
              isYoutubeHost(url) else { return false }

        let isRootURL = isYoutubeRootURL(url)
        let isInChannel = await isCurrentWebViewInAYoutubeChannel(webView)
        return isRootURL || isInChannel
    }

    private func isYoutubeRootURL(_ url: URL) -> Bool {
        guard let urlComponents = URLComponents(string: url.absoluteString) else { return false }
        return urlComponents.scheme == "https" &&
               isYoutubeHost(url) &&
               urlComponents.path == "/"
    }

    private func isYoutubeHost(_ url: URL) -> Bool {
        guard let urlComponents = URLComponents(string: url.absoluteString) else { return false }
        return urlComponents.host == "www.youtube.com"
    }

    private func isCurrentWebViewInAYoutubeChannel(_ webView: WKWebView) async -> Bool {
        do {
            return try await webView.evaluateJavaScript(DuckPlayerOnboardingLocationValidator.youtubeChannelCheckScript) as Bool? ?? false
        } catch {
            return false
        }
    }
}
