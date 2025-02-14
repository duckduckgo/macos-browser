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
import PixelKit
import DuckPlayer

protocol YoutubeScriptsProvider {
    var youtubeOverlayScript: YoutubeOverlayUserScript? { get }
    var youtubePlayerUserScript: YoutubePlayerUserScript? { get }
}
extension UserScripts: YoutubeScriptsProvider {}

final class DuckPlayerTabExtension {
    private let duckPlayer: DuckPlayer
    private let isBurner: Bool
    private var cancellables = Set<AnyCancellable>()
    private var youtubePlayerCancellables = Set<AnyCancellable>()
    private var shouldOpenInNewTab: Bool  {
        preferences.isOpenInNewTabSettingsAvailable &&
        preferences.duckPlayerOpenInNewTab &&
        preferences.duckPlayerMode != .disabled
    }
    private var shouldOpenDuckPlayerDirectly: Bool {
        preferences.duckPlayerMode == .enabled
    }
    private let preferences: DuckPlayerPreferences

    private weak var webView: WKWebView? {
        didSet {
            youtubeOverlayScript?.webView = webView
            youtubePlayerScript?.webView = webView
            if duckPlayerOverlayUsagePixels.webView == nil {
                duckPlayerOverlayUsagePixels.webView = webView
            }
        }
    }
    private weak var youtubeOverlayScript: YoutubeOverlayUserScript?
    private weak var youtubePlayerScript: YoutubePlayerUserScript?
    private let onboardingDecider: DuckPlayerOnboardingDecider
    private var shouldSelectNextNewTab: Bool?
    private var duckPlayerOverlayUsagePixels: DuckPlayerOverlayPixelFiring
    private var duckPlayerModeCancellable: AnyCancellable?

    init(duckPlayer: DuckPlayer,
         isBurner: Bool,
         scriptsPublisher: some Publisher<some YoutubeScriptsProvider, Never>,
         webViewPublisher: some Publisher<WKWebView, Never>,
         preferences: DuckPlayerPreferences = .shared,
         onboardingDecider: DuckPlayerOnboardingDecider,
         duckPlayerOverlayPixels: DuckPlayerOverlayPixelFiring = DuckPlayerOverlayUsagePixels()) {
        self.duckPlayer = duckPlayer
        self.isBurner = isBurner
        self.preferences = preferences
        self.onboardingDecider = onboardingDecider
        self.duckPlayerOverlayUsagePixels = duckPlayerOverlayPixels

        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView
        }.store(in: &cancellables)

        scriptsPublisher.sink { [weak self] scripts in
            self?.youtubeOverlayScript = scripts.youtubeOverlayScript
            self?.youtubePlayerScript = scripts.youtubePlayerUserScript
            self?.youtubePlayerScript?.webView = self?.webView
            self?.youtubeOverlayScript?.delegate = self
            self?.youtubeOverlayScript?.webView = self?.webView

            DispatchQueue.main.async { [weak self] in
                self?.setUpYoutubeScriptsIfNeeded(for: self?.webView?.url)
            }
        }.store(in: &cancellables)

        // Add a DuckPlayerMode observer
        setupPlayerModeObserver()

    }

    deinit {
        duckPlayerModeCancellable?.cancel()
        duckPlayerModeCancellable = nil
    }

    @MainActor
    private func setUpYoutubeScriptsIfNeeded(for url: URL?) {
        youtubePlayerCancellables.removeAll()
        guard duckPlayer.isAvailable else { return }

        onboardingDecider.valueChangedPublisher.sink {[weak self] _ in
            guard let self = self else { return }

            self.youtubeOverlayScript?.userUISettingsUpdated(uiValues: UIUserValues(onboardingDecider: self.onboardingDecider))
        }.store(in: &youtubePlayerCancellables)

        if let hostname = url?.host, let script = youtubeOverlayScript {
            if script.messageOriginPolicy.isAllowed(hostname) {
                duckPlayer.$mode
                        .dropFirst()
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] playerMode in
                            guard let self else { return }
                            let userValues = UserValues(duckPlayerMode: playerMode, overlayInteracted: self.duckPlayer.overlayInteracted)
                            self.youtubeOverlayScript?.userValuesUpdated(userValues: userValues)
                        }
                        .store(in: &youtubePlayerCancellables)
            }
        }

        if url?.isDuckPlayer == true {
            youtubePlayerScript?.isEnabled = true

            duckPlayer.$mode
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] playerMode in
                    guard let self else { return }
                    let userValues = UserValues(duckPlayerMode: playerMode, overlayInteracted: self.duckPlayer.overlayInteracted)
                    self.youtubePlayerScript?.userValuesUpdated(userValues: userValues)
                }
                .store(in: &youtubePlayerCancellables)
        } else {
            youtubePlayerScript?.isEnabled = false
        }
    }

    private func fireOverlayShownPixelIfNeeded(url: URL) {

        guard duckPlayer.isAvailable,
              duckPlayer.mode == .alwaysAsk,
              url.isYoutubeWatch else {
            return
        }

        // Static variable for debounce logic
        let debounceInterval: TimeInterval = 1.0
        let now = Date()

        struct Debounce {
            static var lastFireTime: Date?
        }

        // Check debounce condition and update timestamp if firing
        guard Debounce.lastFireTime == nil || now.timeIntervalSince(Debounce.lastFireTime!) >= debounceInterval else {
            return
        }

        Debounce.lastFireTime = now
        PixelKit.fire(GeneralPixel.duckPlayerOverlayYoutubeImpressions)
    }

    private func setupPlayerModeObserver() {
        duckPlayerModeCancellable = preferences.$duckPlayerMode
            .sink { [weak self] mode in
                self?.duckPlayerOverlayUsagePixels.duckPlayerMode = mode
        }
    }

}

extension DuckPlayerTabExtension: YoutubeOverlayUserScriptDelegate {

    func youtubeOverlayUserScriptDidRequestDuckPlayer(with url: URL, in webView: WKWebView) {
        if duckPlayer.mode == .enabled {
            PixelKit.fire(GeneralPixel.duckPlayerViewFromYoutubeAutomatic)
        }

        var shouldRequestNewTab = shouldOpenInNewTab

        // PopUpWindows don't support tabs
        if let window = webView.window, window is PopUpWindow {
            shouldRequestNewTab = false
        }

        let isRequestingNewTab = NSApp.isCommandPressed || shouldRequestNewTab
        if isRequestingNewTab {
            shouldSelectNextNewTab = NSApp.isShiftPressed || shouldOpenInNewTab
            webView.loadInNewWindow(url)
        } else {
            shouldSelectNextNewTab = nil
            webView.load(URLRequest(url: url))
        }
    }

}

extension DuckPlayerTabExtension: NewWindowPolicyDecisionMaker {

    func decideNewWindowPolicy(for navigationAction: WKNavigationAction) -> NavigationDecision? {
        // if a link was clicked inside duckplayer (like a recommendation)
        // and has target=_blank - then we want to prevent a new tab
        // opening, and just load it inside the current one instead
        if navigationAction.targetFrame == nil,
           navigationAction.safeSourceFrame?.webView?.url?.isDuckPlayer == true,
           navigationAction.request.url?.isYoutubeVideoRecommendation == true,
           let webView, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
            return .cancel
        }

        if let shouldSelectNextNewTab {
            defer {
                self.shouldSelectNextNewTab = nil
            }
            return .allow(.tab(selected: shouldSelectNextNewTab, burner: isBurner))
        }
        return nil
    }

}

extension DuckPlayerTabExtension: NavigationResponder {
    // swiftlint:disable cyclomatic_complexity
    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        // only proceed when Private Player is enabled

        guard duckPlayer.isAvailable, duckPlayer.mode != .disabled else {
            return decidePolicyWithDisabledDuckPlayer(for: navigationAction)
        }

        // Fires the Overlay Shown Pixel if not coming from DuckPlayer's Watch in Youtube
        if !navigationAction.sourceFrame.url.isDuckPlayer {
            fireOverlayShownPixelIfNeeded(url: navigationAction.url)
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

        // Duck Player Overlay Reload Pixel
        if case .reload = navigationAction.navigationType {
            duckPlayerOverlayUsagePixels.fireReloadPixelIfNeeded(url: navigationAction.url)
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
        // todo(shane): Ensure this restriction still works
        if navigationAction.url.path == YoutubePlayerNavigationHandler.htmlTemplatePath {
            return .cancel
        }

        // Always allow loading Private Player URLs (local HTML)
        if navigationAction.url.isDuckURLScheme || navigationAction.url.isDuckPlayer {
            if navigationAction.request.allHTTPHeaderFields?["Referer"] == URL.duckDuckGo.absoluteString {
                PixelKit.fire(GeneralPixel.duckPlayerViewFromSERP)

                if shouldOpenInNewTab,
                   let url = webView?.url, !url.isEmpty, !url.isYoutubeVideo {
                    shouldSelectNextNewTab = true
                    webView?.loadInNewWindow(navigationAction.url)
                    return .cancel
                }
            }
            return .allow
        }

        // Navigating to a Youtube URL
        return handleYoutubeNavigation(for: navigationAction)
    }
    // swiftlint:enable cyclomatic_complexity

    @MainActor
    private func handleYoutubeNavigation(for navigationAction: NavigationAction) -> NavigationActionPolicy? {
        guard navigationAction.url.isYoutubeVideo,
              let (videoID, timestamp) = navigationAction.url.youtubeVideoParams else {
            return .next
        }

        if shouldOpenDuckPlayerDirectly,
           let url = webView?.url, !url.isEmpty, !url.isYoutubeVideo {
            webView?.stopAllMediaPlayback()
            webView?.loadInNewWindow(navigationAction.url)
            return .cancel
        }

        return decidePolicy(for: navigationAction, withYoutubeVideoID: videoID, timestamp: timestamp)
    }

    func navigation(_ navigation: Navigation, didSameDocumentNavigationOf navigationType: WKSameDocumentNavigationType) {
        // Navigating to a Youtube URL without page reload
        if shouldOpenDuckPlayerDirectly,
           case .sessionStatePush = navigationType,
           let webView, let url = webView.url,
           url.isYoutubeVideo,
           let (videoID, timestamp) = url.youtubeVideoParams {

            webView.goBack()
            webView.load(URLRequest(url: .duckPlayer(videoID, timestamp: timestamp)))
        }

        // Fire Overlay Shown Pixels
        fireOverlayShownPixelIfNeeded(url: navigation.url)

    }

    @MainActor
    private func decidePolicyWithDisabledDuckPlayer(for navigationAction: NavigationAction) -> NavigationActionPolicy? {
        // When the feature is disabled but the webView still gets a Private Player URL,
        // convert it back to a regular YouTube video URL.
        if navigationAction.url.isDuckPlayer {
            guard let (videoID, timestamp) = navigationAction.url.youtubeVideoParams else {
                return .cancel
            }

            if let mainFrame = navigationAction.mainFrameTarget {
                return .redirect(mainFrame) { navigator in
                    navigator.load(URLRequest(url: .youtube(videoID, timestamp: timestamp)))
                }
            }
        }
        return .next
    }

    @MainActor
    private func decidePolicy(for navigationAction: NavigationAction, withYoutubeVideoID videoID: String, timestamp: String?) -> NavigationActionPolicy? {
        // Prevent reload loop on back navigation to YT page where the player was enabled.
        //
        // When the Duck Player was set to [Always enable] on a YT page and we‘re navigating back to a YouTube video page,
        // the DP would automatically load on that YouTube video, effectively cancelling the back navigation.
        // We need to go 2 sites back. That YouTube page wasn't really viewed by the user, but it was pushed on the
        // navigation stack and immediately replaced with Private Player. That's why skipping it while going back makes sense.
        //
        // SERP+Video -> YT [enable mode always] -> Duck Player ⏎
        // SERP+Video ⏪︎⏪︎ YT (redirected to DP) <- Duck Player
        //
        if case .backForward(distance: let distance) = navigationAction.navigationType, distance < 0,
           shouldOpenDuckPlayerDirectly,
           navigationAction.sourceFrame.url.isDuckPlayer,
           navigationAction.url.youtubeVideoID == navigationAction.sourceFrame.url.youtubeVideoID,
           let mainFrame = navigationAction.mainFrameTarget {

            return .redirect(mainFrame) { navigator in
                navigator.goBack(withExpectedNavigationType: .backForward(distance: -1)) // to SERP+Video
            }
        }

        // “Watch in YouTube” selected
        // when currently displayed content is the Duck Player and loading a YouTube URL, don‘t override it
        if didUserSelectWatchInYoutubeFromDuckPlayer(navigationAction, preferences: preferences, videoID: videoID) {
            duckPlayer.setNextVideoToOpenOnYoutube()
            PixelKit.fire(GeneralPixel.duckPlayerWatchOnYoutube)
            return .next

        // If this is a child tab of a Duck Player and it's loading a YouTube URL, don‘t override it
        } else if navigationAction.isTargetingNewWindow,
                  navigationAction.sourceFrame.url.isDuckPlayer,
                  navigationAction.sourceFrame.url.youtubeVideoID == videoID {
            return .next
        }

        // Redirect youtube urls to Duck Player when [Always enable] preference is set
        if shouldOpenDuckPlayerDirectly
            // - or - recommendations must always be opened in the Duck Player
            || (navigationAction.sourceFrame.url.isDuckPlayer && navigationAction.url.isYoutubeVideoRecommendation),
           let mainFrame = navigationAction.mainFrameTarget {

            switch navigationAction.navigationType {
            case .custom, .redirect(.server):
                PixelKit.fire(GeneralPixel.duckPlayerViewFromOther)
            case .other:
                if navigationAction.request.allHTTPHeaderFields?["Referer"] == URL.duckDuckGo.absoluteString {
                    PixelKit.fire(GeneralPixel.duckPlayerViewFromSERP)
                }
            default:
                break
            }

            return .redirect(mainFrame) { navigator in
                navigator.load(URLRequest(url: .duckPlayer(videoID, timestamp: timestamp)))
            }
        }

        return .next
    }

    private func didUserSelectWatchInYoutubeFromDuckPlayer(_ navigationAction: NavigationAction, preferences: DuckPlayerPreferences, videoID: String) -> Bool {
        let url = preferences.duckPlayerOpenInNewTab ? navigationAction.sourceFrame.url : navigationAction.targetFrame?.url
        return url?.isDuckPlayer == true && url?.youtubeVideoID == videoID
    }

    func didCommit(_ navigation: Navigation) {
        guard duckPlayer.isAvailable, duckPlayer.mode != .disabled else {
            return
        }
        if navigation.url.isDuckPlayer {
            let setting = preferences.duckPlayerMode == .enabled ? "always" : "default"
            let newTabSettings = preferences.duckPlayerOpenInNewTab ? "true" : "false"
            let autoplay = preferences.duckPlayerAutoplay ? "true" : "false"

            let params = ["setting": setting,
                          "newtab": newTabSettings,
                          "autoplay": autoplay]

            PixelKit.fire(GeneralPixel.duckPlayerDailyUniqueView,
                          frequency: .legacyDaily,
                          withAdditionalParameters: params)

        }
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
    var duckPlayer: DuckPlayerExtensionProtocol? {
        resolve(DuckPlayerTabExtension.self)
    }
}
