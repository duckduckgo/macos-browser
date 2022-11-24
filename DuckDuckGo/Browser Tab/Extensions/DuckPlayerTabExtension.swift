//
//  DuckPlayerTabExtension.swift
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

import Combine
import Foundation

final class DuckPlayerTabExtension {
    
    @Injected(default: .shared, .testable) static var privatePlayer: PrivatePlayer
    
    private var userScriptsCancellable: AnyCancellable?
    private var youtubePlayerCancellables: Set<AnyCancellable> = []
    
    private weak var tab: Tab?
    private weak var youtubeOverlayScript: YoutubeOverlayUserScript?
    private weak var youtubePlayerScript: YoutubePlayerUserScript?
    
    init(tab: Tab) {
        self.tab = tab
        userScriptsCancellable = tab.userScriptsPublisher.sink { [weak self] userScripts in
            self?.youtubeOverlayScript = userScripts?.youtubeOverlayScript
            self?.youtubeOverlayScript?.delegate = self
            self?.youtubePlayerScript = userScripts?.youtubePlayerUserScript
            self?.setUpYoutubeScriptsIfNeeded(in: self?.tab?.webView)
        }
    }
    
    // TODO: func goBack() {
    //    if Dependencies.privatePlayer.goBackSkippingLastItemIfNeeded(for: webView) {
    //        return
    //    }
    // }

    func setUpYoutubeScriptsIfNeeded(in webView: WebView?) {
        guard Self.privatePlayer.isAvailable,
              let webView = webView
        else {
            return
        }

        youtubePlayerCancellables.removeAll()

        // only send push updates on macOS 11+ where it's safe to call window.* messages in the browser
        let canPushMessagesToJS: Bool = {
            if #available(macOS 11, *) {
                return true
            } else {
                return false
            }
        }()

        if webView.url?.host?.droppingWwwPrefix() == "youtube.com" && canPushMessagesToJS {
            Self.privatePlayer.$mode
                .dropFirst()
                .sink { [weak self] playerMode in
                    guard let self = self else {
                        return
                    }
                    let userValues = YoutubeOverlayUserScript.UserValues(
                        privatePlayerMode: playerMode,
                        overlayInteracted: Self.privatePlayer.overlayInteracted
                    )
                    self.youtubeOverlayScript?.userValuesUpdated(userValues: userValues, inWebView: webView)
                }
                .store(in: &youtubePlayerCancellables)
        }

        if webView.url?.isPrivatePlayerScheme == true {
            youtubePlayerScript?.isEnabled = true

            if canPushMessagesToJS {
                Self.privatePlayer.$mode
                    .map { $0 == .enabled }
                    .sink { [weak self] shouldAlwaysOpenPrivatePlayer in
                        guard let self = self else {
                            return
                        }
                        self.youtubePlayerScript?.setAlwaysOpenInPrivatePlayer(shouldAlwaysOpenPrivatePlayer, inWebView: webView)
                    }
                    .store(in: &youtubePlayerCancellables)
            }
        } else {
            youtubePlayerScript?.isEnabled = false
        }
    }

}

extension DuckPlayerTabExtension: YoutubeOverlayUserScriptDelegate {

    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL) {
        let isRequestingNewTab = NSApp.isCommandPressed
        if isRequestingNewTab {
            let shouldSelectNewTab = NSApp.isShiftPressed
            self.tab?.webView.load(url, in: .blank, windowFeatures: shouldSelectNewTab ? .selectedTab : .backgroundTab)
        } else {
            let content = Tab.TabContent.contentFromURL(url)
            self.tab?.setContent(content)
        }
    }

}

extension DuckPlayerTabExtension: NavigationResponder {

    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {

        guard Self.privatePlayer.isAvailable, Self.privatePlayer.mode != .disabled else {
            // When the feature is disabled but the webView still gets a Private Player URL,
            // convert it back to a regular YouTube video URL.
            if navigationAction.request.url?.isPrivatePlayerScheme == true,
               let (videoID, timestamp) = navigationAction.request.url?.youtubeVideoParams {

                return .redirect(to: .youtube(videoID, timestamp: timestamp))
            }
            return .next
        }

        // Don't allow loading Private Player HTML directly
        if navigationAction.request.url?.path == YoutubePlayerNavigationHandler.htmlTemplatePath {
            return .cancel
        }

        // Always allow loading Private Player URLs (local HTML)
        if navigationAction.request.url?.isPrivatePlayerScheme == true {
            return .allow
        }

        // We only care about YouTube video URLs loaded into main frame or within a Private Player
        guard navigationAction.isTargetingMainFrame || webView.url?.isPrivatePlayer == true, navigationAction.request.url?.isYoutubeVideo == true else {
            return .next
        }

        let alwaysOpenInPrivatePlayer = Self.privatePlayer.mode == .enabled

        // When Private Player is in enabled state (always open), and it's a back navigation from PP to a YouTube video page,
        // the PP would automatically load on that YouTube video, effectively cancelling the back navigation.
        // We need to go 2 sites back. That YouTube page wasn't really viewed by the user, but it was pushed on the
        // navigation stack and immediately replaced with Private Player. That's why skipping it while going back makes sense.
        if alwaysOpenInPrivatePlayer && isGoingBackFromPrivatePlayerToYoutubeVideo(for: navigationAction, in: webView.tab) {
            _=webView.goBack()
            return .cancel
        }

        let didSelectRecommendationFromPrivatePlayer = webView.url?.isPrivatePlayer == true && navigationAction.request.url?.isYoutubeVideoRecommendation == true

        // Recommendations must always be opened in Private Player.
        guard alwaysOpenInPrivatePlayer || didSelectRecommendationFromPrivatePlayer, let (videoID, timestamp) = navigationAction.request.url?.youtubeVideoParams else {
            return .next
        }

        // If this is a child tab of a Private Player and it's loading a YouTube URL, don't override it ("Watch in YouTube").
        if case .privatePlayer(let parentVideoID, _) = webView.tab?.parentTab?.content, parentVideoID == videoID {
            return .next
        }

        // Otherwise load priate player unless it's already loaded.
        guard case .privatePlayer(let currentVideoID, _) = webView.tab?.content, currentVideoID == videoID, webView.url?.isPrivatePlayer == true else {
            return .redirect(to: .privatePlayer(videoID, timestamp: timestamp))
        }
        return .next
    }

    private func isGoingBackFromPrivatePlayerToYoutubeVideo(for navigationAction: WKNavigationAction, in tab: Tab?) -> Bool {
        guard navigationAction.navigationType == .backForward,
              let url = tab?.webView.backForwardList.currentItem?.url,
              let forwardURL = tab?.webView.backForwardList.forwardItem?.url
        else {
            return false
        }

        return url.isYoutubeVideo && forwardURL.isPrivatePlayer && url.youtubeVideoID == forwardURL.youtubeVideoID
    }

    func webView(_ webView: WebView, didFinish navigation: WKNavigation, with request: URLRequest) {
        setUpYoutubeScriptsIfNeeded(in: webView)
    }

}
