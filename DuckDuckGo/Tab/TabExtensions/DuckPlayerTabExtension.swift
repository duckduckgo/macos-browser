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
import Common
import ContentBlocking
import Foundation
import Navigation

protocol YoutubeScriptsProvider {
    var youtubeOverlayScript: YoutubeOverlayUserScript? { get }
    var youtubePlayerUserScript: YoutubePlayerUserScript? { get }
}
extension UserScripts: YoutubeScriptsProvider {}

final class DuckPlayerTabExtension {
    private let duckPlayer: DuckPlayer
    private var cancellables = Set<AnyCancellable>()
    private var youtubePlayerCancellables = Set<AnyCancellable>()

    private weak var youtubeOverlayScript: YoutubeOverlayUserScript?
    private weak var youtubePlayerScript: YoutubePlayerUserScript?

    private var shouldSelectNextNewTab: Bool?

    init(duckPlayer: DuckPlayer,
         scriptsPublisher: some Publisher<some YoutubeScriptsProvider, Never>) {
        self.duckPlayer = duckPlayer

        scriptsPublisher.sink { [weak self] scripts in
            self?.youtubeOverlayScript = scripts.youtubeOverlayScript
            self?.youtubePlayerScript = scripts.youtubePlayerUserScript
            self?.youtubeOverlayScript?.delegate = self

            self?.setUpYoutubeScriptsIfNeeded(for: nil)
        }.store(in: &cancellables)
    }

    private func setUpYoutubeScriptsIfNeeded(for url: URL?) {
        youtubePlayerCancellables.removeAll()
        guard duckPlayer.isAvailable else { return }

        // only send push updates on macOS 11+ where it's safe to call window.* messages in the browser
        let canPushMessagesToJS: Bool = {
            if #available(macOS 11, *) {
                return true
            } else {
                return false
            }
        }()

        if url?.host?.droppingWwwPrefix() == "youtube.com" && canPushMessagesToJS {
            duckPlayer.$mode
                .dropFirst()
                .sink { [weak self] playerMode in
                    guard let self = self else {
                        return
                    }
                    let userValues = YoutubeOverlayUserScript.UserValues(
                        duckPlayerMode: playerMode,
                        overlayInteracted: self.duckPlayer.overlayInteracted
                    )
                    self.youtubeOverlayScript?.userValuesUpdated(userValues: userValues)
                }
                .store(in: &youtubePlayerCancellables)
        }

        if url?.isDuckPlayerScheme == true {
            youtubePlayerScript?.isEnabled = true

            if canPushMessagesToJS {
                duckPlayer.$mode
                    .map { $0 == .enabled }
                    .sink { [weak self] shouldAlwaysOpenDuckPlayer in
                        guard let self = self else {
                            return
                        }
                        self.youtubeOverlayScript?.setAlwaysOpenInDuckPlayer(shouldAlwaysOpenDuckPlayer)
                    }
                    .store(in: &youtubePlayerCancellables)
            }
        } else {
            youtubePlayerScript?.isEnabled = false
        }
    }

}

extension DuckPlayerTabExtension: YoutubeOverlayUserScriptDelegate {

    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL, in webView: WKWebView) {
        // to be standardised across the app
        let isRequestingNewTab = NSApp.isCommandPressed
        if isRequestingNewTab {
            shouldSelectNextNewTab = NSApp.isShiftPressed
            webView.loadInNewWindow(url)
        } else {
            shouldSelectNextNewTab = nil
            webView.load(URLRequest(url: url))
        }
    }

}

extension DuckPlayerTabExtension: NewWindowPolicyDecisionMaker {

    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision? {
        if let shouldSelectNextNewTab {
            defer {
                self.shouldSelectNextNewTab = nil
            }
            //TODO!
            return .allow(.tab(selected: shouldSelectNextNewTab, disposable: false))
        }
        return nil
    }

}

extension DuckPlayerTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // only proceed when Private Player is enabled
        guard duckPlayer.isAvailable, duckPlayer.mode != .disabled else {
            return decidePolicyWithDisabledDuckPlayer(for: navigationAction)
        }

        // session restoration will try to load real www.youtube-nocookie.com url
        // we need to redirect it to custom duck:// scheme handler which will load
        // www.youtube-nocookie.com as a simulated request
        if case .sessionRestoration = navigationAction.navigationType,
           navigationAction.url.isDuckPlayer {

            guard let mainFrame = navigationAction.mainFrameTarget,
                  let (videoID, timestamp) = navigationAction.url.youtubeVideoParams else {
                return .cancel
            }

            return .redirect(mainFrame) { navigator in
                // pop current backForwardList item
                navigator.goBack()?.overrideResponders { _, _ in .cancel }
                navigator.load(URLRequest(url: .duckPlayer(videoID, timestamp: timestamp)))
            }
        }

        // when in Private Player, don't directly reload current URL when it‘s a Private Player target URL
        if case .reload = navigationAction.navigationType,
           navigationAction.url.isDuckPlayer {
            guard let mainFrame = navigationAction.mainFrameTarget,
                  let (videoID, timestamp) = navigationAction.url.youtubeVideoParams else {
                return .cancel
            }

            return .redirect(mainFrame) { navigator in
                navigator.load(URLRequest(url: .duckPlayer(videoID, timestamp: timestamp)))
            }
        }

        // Don't allow loading Private Player HTML directly
        if navigationAction.url.path == YoutubePlayerNavigationHandler.htmlTemplatePath {
            return .cancel
        }

        // Always allow loading Private Player URLs (local HTML)
        if navigationAction.url.isDuckPlayerScheme || navigationAction.url.isDuckPlayer {
            return .allow
        }

        // Navigating to a Youtube URL
        if navigationAction.url.isYoutubeVideo,
           let (videoID, timestamp) = navigationAction.url.youtubeVideoParams {
            return decidePolicy(for: navigationAction, withYoutubeVideoID: videoID, timestamp: timestamp)
        }
        return .next
    }

    @MainActor
    func decidePolicyWithDisabledDuckPlayer(for navigationAction: NavigationAction) -> NavigationActionPolicy? {
        // When the feature is disabled but the webView still gets a Private Player URL,
        // convert it back to a regular YouTube video URL.
        if navigationAction.url.isDuckPlayerScheme {
            guard let (videoID, timestamp) = navigationAction.url.youtubeVideoParams,
                  let mainFrame = navigationAction.mainFrameTarget else {
                return .cancel
            }

            return .redirect(mainFrame) { navigator in
                navigator.load(URLRequest(url: .youtube(videoID, timestamp: timestamp)))
            }
        }
        return .next
    }

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, withYoutubeVideoID videoID: String, timestamp: String?) -> NavigationActionPolicy? {
        // Prevent reload loop on back navigation to YT page where the player was enabled.
        //
        // When the Duck Player was set to [Always enable] on a YT page and we‘re navigating back to a YouTube video page,
        // the DP would automatically load on that YouTube video, effectively cancelling the back navigation.
        // We need to go 2 sites back. That YouTube page wasn't really viewed by the user, but it was pushed on the
        // navigation stack and immediately replaced with Private Player. That's why skipping it while going back makes sense.
        //
        // SERP+Video -> YT [enable mode always] -> Duck Player ⏎
        // SERP+Video <<<< YT (redirected to DP) <- Duck Player
        //
        if case .backForward(distance: let distance) = navigationAction.navigationType, distance < 0,
           duckPlayer.mode == .enabled,
           navigationAction.sourceFrame.url.isDuckPlayer,
           navigationAction.url.youtubeVideoID == navigationAction.sourceFrame.url.youtubeVideoID,
           let mainFrame = navigationAction.mainFrameTarget {

            return .redirect(mainFrame) { navigator in
                navigator.goBack(withExpectedNavigationType: .backForward(distance: -1)) // to SERP+Video
            }
        }

        // “Watch in YouTube” selected
        // when currently displayed content is the Duck Player and loading a YouTube URL, don‘t override it
        if navigationAction.targetFrame?.url.isDuckPlayer == true,
           navigationAction.targetFrame?.url.youtubeVideoID == videoID {
            return .next

        // If this is a child tab of a Duck Player and it's loading a YouTube URL, don‘t override it
        } else if navigationAction.isTargetingNewWindow,
                  navigationAction.sourceFrame.url.isDuckPlayer,
                  navigationAction.sourceFrame.url.youtubeVideoID == videoID {
            return .next
        }

        // Redirect youtube urls to Duck Player when [Always enable] preference is set
        if duckPlayer.mode == .enabled
                // - or - recommendations must always be opened in the Duck Player
                || (navigationAction.sourceFrame.url.isDuckPlayer && navigationAction.url.isYoutubeVideoRecommendation),
              let mainFrame = navigationAction.mainFrameTarget {

            return .redirect(mainFrame) { navigator in
                navigator.load(URLRequest(url: .duckPlayer(videoID, timestamp: timestamp)))
            }
        }

        return .next
    }

    @MainActor
    func navigationDidFinish(_ navigation: Navigation) {
        setUpYoutubeScriptsIfNeeded(for: navigation.url)
    }

}

protocol DuckPlayerExtensionProtocol: AnyObject, NavigationResponder, NewWindowPolicyDecisionMaker {
}

extension DuckPlayerTabExtension: DuckPlayerExtensionProtocol, TabExtension {
    func getPublicProtocol() -> DuckPlayerExtensionProtocol { self }
}

extension TabExtensions {
    var duckPlayer: DuckPlayerExtensionProtocol? { resolve(DuckPlayerTabExtension.self) }
}
