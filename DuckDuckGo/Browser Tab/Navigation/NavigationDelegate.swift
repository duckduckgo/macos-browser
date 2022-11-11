//
//  NavigationDelegate.swift
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

import WebKit
import Combine
import Foundation
import BrowserServicesKit

enum NavigationActionPolicy {
    case instantAllow
    case cancel
    case download
    case redirect(request: URLRequest)

    static func redirect(url: URL) -> NavigationActionPolicy {
        return .redirect(request: URLRequest(url: url))
    }
}
protocol PartialNavigationPolicyHandler {
    @MainActor
    func decidePolicy(for navigationAction: NavigationAction) async -> NavigationActionPolicy?
}

enum NavigationType {
    case userEntered
    case linkActivated
    case backForwardNavigation(from: WKBackForwardListItem, to: WKBackForwardListItem, inPageCache: Bool)
    case reload
    case clientRedirect
    case formSubmitted
    case formResubmitted
    case other
}

struct NavigationExpectation {
    let navigation: WKNavigation?
    let type: NavigationType
    let url: URL
    let event: NSEvent?
}

enum NavigationEvent {
    // internal
    case awaitsClientRedirect(URL)
    case awaitsNavigation(URLRequest)
    case awaitsBackForwardNavigation(WKBackForwardListItem)

    // expectation
    case navigationIsExpectedToStart(NavigationExpectation)

    // provisional decision
    case navigationWillStart(WKNavigationAction)

    // navigation
    case navigationDidStart(WKNavigation)
    case didReceiveAuthenticationChallenge(ServerTrust?)
    case didReceiveServerRedirect
    case didReceiveClientRedirect(URL)
    case didReceiveResponse(WKNavigationResponse)
    case didCommitNavigation
    case backForwardListItemAdded(WKBackForwardListItem)
    case webKitNavigationDidFinish(WKNavigation) // -- ? maybe published events should just have name and the Navigation

    // completion
    case renderingProgressDidChange(Int)
    case didFinish // (Navigation)
    case didFail(Error)

    case navigationDidBecomeDownload(WebKitDownload)
    case webProcessDidTerminate(TerminationReason?) //(Navigation)
}

enum TerminationReason: UInt32 {
    case exceededMemoryLimit = 0
    case exceededCPULimit
    case requestedByClient
    case crash
}

typealias Navigation = Array<NavigationEvent>
extension Navigation {

    // MARK: State

    var isExpectingNavigation: Bool {
        switch self.last {
        case .navigationWillStart,
                .awaitsBackForwardNavigation,
                .awaitsClientRedirect,
                .awaitsNavigation:
            return true
        default:
            return false
        }
    }

    var isComplete: Bool {
        switch self.last {
        case .didFinish,
                .didFail,
                .webProcessDidTerminate:
            return true
        default:
            return false
        }
    }

    // MARK: Accessors

    var navigationExpectation: NavigationExpectation? {
        // TODO: not first for redirected navigations
        guard case .navigationIsExpectedToStart(let expectation) = self.first else { return nil }
        return expectation
    }

    var navigationAction: WKNavigationAction? {
        for event in self.reversed() {
            if case .navigationWillStart(let navigationAction) = event {
                return navigationAction
            }
        }
        return nil
    }

    var isUserEntered: Bool {
        if case .userEntered = navigationExpectation?.type { return true }
        return false
    }

    var sourceFrame: WKFrameInfo? {
        navigationAction?.sourceFrame
    }

    var targetFrame: WKFrameInfo? {
        navigationAction?.targetFrame
    }

    var isTargetingMainFrame: Bool {
        for event in self.reversed() {
            switch event {
            case .navigationWillStart(let navigationAction):
                return navigationAction.isTargetingMainFrame
            case .didReceiveResponse(let navigationResponse):
                return navigationResponse.isForMainFrame
            default:
                // TODO: navigation expectation should return true
                continue
            }
        }
        return false
    }

}

final class NavigationDelegate: NSObject, WebViewNavigationDelegate {
    weak var tab: Tab?

    var expectedNavigation: Navigation?
    var mainFrameNavigation: Navigation?
    var frameNavigations = [FrameHandle: Navigation]()

    private let navigationEventsSubject = PassthroughSubject<NavigationEvent, Never>()
    var navigationEventsPublisher: AnyPublisher<NavigationEvent, Never> {
        navigationEventsSubject.eraseToAnyPublisher()
    }

    var navigationPolicyHandlers = [PartialNavigationPolicyHandler]()
    private var currentBackForwardItem: WKBackForwardListItem?

    // TODO:
    // tests for protocol methods
    // tests for navigation events order including redirect
    // integration tests for partial navigation handlers

    func webView(_ webView: WKWebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest) {

        //        navigationEventsSubject(.willStart(Navigation(navigation: navigation)))
        print(navigation, request)
    }

    func webView(_ webView: WKWebView, willStartReloadNavigation navigation: WKNavigation?) {
        print(navigation)
    }

    func webView(_ webView: WKWebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool) {
        // called twice: before _webViewDidEndNavigationGesture: and after decidePolicyForNavigationAction:
        if case .backForwardNavigation(from: _, to: backForwardListItem, inPageCache: _) = mainFrameNavigation?.navigationExpectation?.type {
            // this is a second call: ignore
            return
        }
        print("willGoToBackForwardListItem", backForwardListItem.url, backForwardListItem.title)
    }

    @objc(_webViewDidBeginNavigationGesture:)
    func webViewDidBeginNavigationGesture(_ webView: WKWebView) {
        print(webView)
    }

    // Item is nil if the gesture ended without navigation.
    @objc(_webViewDidEndNavigationGesture:withNavigationToBackForwardListItem:)
    func webView(_ webView: WKWebView, didEndNavigationGestureWithNavigationTo backForwardListItem: WKBackForwardListItem?) {
        print(backForwardListItem)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        //        let currentNavigation = self.mainFrameNavigation ?? {
        //            self.mainFrameNavigation = Navigation(navigationAction: navigationAction)
        //        }()

        if navigationAction.isTargetingMainFrame {
            print(navigationAction, navigationAction.value(forKey: "_mainFrameNavigation"))
            if navigationAction.request.url?.host == "www.zara.com" {
                DispatchQueue.main.async {
                    webView.load(.duckDuckGo)
                }
            }
        }
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        decisionHandler(.allow)
        //        }
        return
        let navigationAction = NavigationAction(navigationAction: navigationAction, userEntered: false, currentBackForwardItem: webView.backForwardList.currentItem)
        Task { @MainActor in
            switch await self.decidePolicy(for: navigationAction) {
            case .instantAllow:
                decisionHandler(.allow)
            case .cancel:
                decisionHandler(.cancel)
            case .redirect(request: let request):
                //                self.invalidateBackItemIfNeeded(for: navigationAction)
                decisionHandler(.cancel)
                webView.load(request) // TODO: may it hang here
            case .download:
                // register the navigationAction for legacy _WKDownload to be called back on the Tab
                // further download will be passed to webView:navigationAction:didBecomeDownload:
                //                decisionHandler(.download(navigationAction, using: webView))
                fatalError()
            }
        }
    }

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction) async -> NavigationActionPolicy {
        //        let context = NavigationActionContext(currentContent: content,
        // TODO: can it be replaced with checking the sourceFrame?
        //                                              parentTabContent: parentTab?.content,
        //                                              currentURL: webView.url,
        //                                              backForwardList: webView.backForwardList)

        for handler in navigationPolicyHandlers {
            if let policy = await handler.decidePolicy(for: navigationAction) {
                return policy
            }
        }
        return .instantAllow


        //
        //        let isLinkActivated = navigationAction.navigationType == .linkActivated
        //        let isNavigatingAwayFromPinnedTab: Bool = {
        //            let isNavigatingToAnotherDomain = navigationAction.request.url?.host != url?.host
        //            let isPinned = pinnedTabsManager.isTabPinned(self)
        //            return isLinkActivated && isPinned && isNavigatingToAnotherDomain
        //        }()
        //
        //        // < -- LinkProtection
        //
        //        let isMiddleButtonClicked = navigationAction.isMiddleClick
        //
        //        let isRequestingNewTab = (isLinkActivated && NSApp.isCommandPressed) || isMiddleButtonClicked || isNavigatingAwayFromPinnedTab
        //        let shouldSelectNewTab = NSApp.isShiftPressed || (isNavigatingAwayFromPinnedTab && !isMiddleButtonClicked && !NSApp.isCommandPressed)
        //
        //
        //        webView.customUserAgent = UserAgent.for(navigationAction.request.url)
        //
        //        if navigationAction.isTargetingMainFrame, navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
        //            lastUpgradedURL = nil
        //        }
        //
        //        if navigationAction.isTargetingMainFrame, navigationAction.navigationType == .backForward {
        //            adClickAttributionLogic.onBackForwardNavigation(mainFrameURL: webView.url)
        //        }
        //
        //        // < -- Trim Referrer
        //
        //        if navigationAction.isTargetingMainFrame {
        //            if navigationAction.navigationType == .backForward,
        //               self.webView.frozenCanGoForward != nil {
        //
        //                // Auto-cancel simulated Back action when upgrading to HTTPS or GPC from Client Redirect
        //                self.webView.frozenCanGoForward = nil
        //                self.webView.frozenCanGoBack = nil
        //
        //                return .cancel
        //
        //            } else if navigationAction.navigationType != .backForward, !isRequestingNewTab,
        //                      let request = GPCRequestFactory.shared.requestForGPC(basedOn: navigationAction.request) {
        //                self.invalidateBackItemIfNeeded(for: navigationAction)
        //                defer {
        //                    _ = webView.load(request)
        //                }
        //                return .cancel
        //            }
        //        }
        //
        //        if navigationAction.isTargetingMainFrame {
        //            if navigationAction.request.url != currentDownload || navigationAction.isUserInitiated {
        //                currentDownload = nil
        //            }
        //            if navigationAction.request.url != self.clientRedirectedDuringNavigationURL {
        //                self.clientRedirectedDuringNavigationURL = nil
        //            }
        //        }
        //
        //        self.resetConnectionUpgradedTo(navigationAction: navigationAction)
        //
        //        if isRequestingNewTab {
        //            defer {
        //                delegate?.tab(
        //                    self,
        //                    requestedNewTabWith: navigationAction.request.url.map { .contentFromURL($0) } ?? .none,
        //                    selected: shouldSelectNewTab)
        //            }
        //            return .cancel
        //        } else if isLinkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed {
        //            return .download(navigationAction, using: webView)
        //        }
        //
        //        guard let url = navigationAction.request.url, url.scheme != nil else {
        //            self.willPerformNavigationAction(navigationAction)
        //            return .allow
        //        }
        //
        //        if navigationAction.shouldDownload {
        //            // register the navigationAction for legacy _WKDownload to be called back on the Tab
        //            // further download will be passed to webView:navigationAction:didBecomeDownload:
        //            return .download(navigationAction, using: webView)
        //
        //        } else if url.isExternalSchemeLink {
        //            // always allow user entered URLs
        //            if !userEnteredUrl {
        //                // ignore <iframe src="custom://url">
        //                // ignore 2nd+ external scheme navigation not initiated by user
        //                guard navigationAction.sourceFrame.isMainFrame,
        //                      !self.externalSchemeOpenedPerPageLoad || navigationAction.isUserInitiated
        //                else { return .cancel }
        //
        //                self.externalSchemeOpenedPerPageLoad = true
        //            }
        //            self.requestOpenExternalURL(url, forUserEnteredURL: userEnteredUrl)
        //            return .cancel
        //        }
        //
        //        if navigationAction.isTargetingMainFrame {
        //            let result = await PrivacyFeatures.httpsUpgrade.upgrade(url: url)
        //            switch result {
        //            case let .success(upgradedURL):
        //                if lastUpgradedURL != upgradedURL {
        //                    urlDidUpgrade(upgradedURL, navigationAction: navigationAction)
        //                    return .cancel
        //                }
        //            case .failure:
        //                if !url.isDuckDuckGo {
        //                    await prepareForContentBlocking()
        //                }
        //            }
        //        }
        //
        //        toggleFBProtection(for: url)
        //        willPerformNavigationAction(navigationAction)
        //
        //        return .allow
    }

    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        defer {
            var serverTrust: ServerTrust?
            if let host = webView.url?.host,
               host == challenge.protectionSpace.host,
               let secTrust = challenge.protectionSpace.serverTrust {
                serverTrust = ServerTrust(host: host, secTrust: secTrust)
            }

            navigationEventsSubject.send(.didReceiveAuthenticationChallenge(serverTrust))
        }

        //        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
        //           let delegate = delegate {
        //            delegate.tab(self, requestedBasicAuthenticationChallengeWith: challenge.protectionSpace, completionHandler: completionHandler)
        //            return
        //        }

        completionHandler(.performDefaultHandling, nil)
        //            self.serverTrust = serverTrust
    }

    private func urlDidUpgrade(_ upgradedURL: URL,
                               navigationAction: WKNavigationAction) {
        //        lastUpgradedURL = upgradedURL
        invalidateBackItemIfNeeded(for: navigationAction)
        //        webView.load(upgradedURL)
        //        setConnectionUpgradedTo(upgradedURL, navigationAction: navigationAction)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation) {
        //        isBeingRedirected = true
    }

    // FIXME: We should assert that navigation is not null here, but it's currently null for some navigations through the back/forward cache.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation) {
        //        if let url = webView.url?.absoluteString,
        //           !["about:home", URL.duckDuckGo.absoluteString].contains(url) {
        //            webView.load(.duckDuckGo)
        //        }
        //        webView.perform("_killWebContentProcess")
        //        isBeingRedirected = false
        //        if content.isUrl, let url = webView.url {
        //            addVisit(of: url)
        //        }
        //        webViewDidCommitNavigationPublisher.send()
    }

    @MainActor
    private func prepareForContentBlocking() async {
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
        //        if !userContentController.contentBlockingAssetsInstalled {
        //            cbaTimeReporter?.tabWillWaitForRulesCompilation(self.instrumentation.currentTabIdentifier)
        //            await userContentController.awaitContentBlockingAssetsInstalled()
        //            cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(self.instrumentation.currentTabIdentifier)
        //        } else {
        //            cbaTimeReporter?.reportNavigationDidNotWaitForRules()
        //        }
    }

    private func toggleFBProtection(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
        let privacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig

        let featureEnabled = privacyConfiguration.isFeature(.clickToPlay, enabledForDomain: url.host)
        //        setFBProtection(enabled: featureEnabled)
    }

    private func willPerformNavigationAction(_ navigationAction: WKNavigationAction) {
        guard navigationAction.isTargetingMainFrame else { return }

        //        self.externalSchemeOpenedPerPageLoad = false
        //        delegate?.tabWillStartNavigation(self, isUserInitiated: navigationAction.isUserInitiated)
    }

    private func invalidateBackItemIfNeeded(for navigationAction: WKNavigationAction) {
        //        guard let url = navigationAction.request.url,
        //              url == self.clientRedirectedDuringNavigationURL
        //        else { return }
        //
        //        // Cancelled & Upgraded Client Redirect URL leaves wrong backForwardList record
        //        // https://app.asana.com/0/inbox/1199237043628108/1201280322539473/1201353436736961
        //        self.webView.goBack()
        //        self.webView.frozenCanGoBack = self.webView.canGoBack
        //        self.webView.frozenCanGoForward = false
    }

    @MainActor
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        //        userEnteredUrl = false // subsequent requests will be navigations
        //
        //        let isSuccessfulResponse = (navigationResponse.response as? HTTPURLResponse)?.validateStatusCode(statusCode: 200..<300) == nil
        //
        //        if !navigationResponse.canShowMIMEType || navigationResponse.shouldDownload {
        //            if navigationResponse.isForMainFrame {
        //                guard currentDownload != navigationResponse.response.url else {
        //                    // prevent download twice
        //                    return .cancel
        //                }
        //                currentDownload = navigationResponse.response.url
        //            }
        //
        //            if isSuccessfulResponse {
        //                // register the navigationResponse for legacy _WKDownload to be called back on the Tab
        //                // further download will be passed to webView:navigationResponse:didBecomeDownload:
        //                return .download(navigationResponse, using: webView)
        //            }
        //        }
        //
        //        if navigationResponse.isForMainFrame && isSuccessfulResponse {
        //            adClickAttributionDetection.on2XXResponse(url: webView.url)
        //        }
        //
        //        await adClickAttributionLogic.onProvisionalNavigation()

        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
        //        delegate?.tabDidStartNavigation(self)
        //
        //        // Unnecessary assignment triggers publishing
        //        if error != nil { error = nil }
        //
        //        invalidateSessionStateData()
        //        resetDashboardInfo()
        //        linkProtection.cancelOngoingExtraction()
        //        linkProtection.setMainFrameUrl(webView.url)
        //        referrerTrimming.onBeginNavigation(to: webView.url)
        //        adClickAttributionDetection.onStartNavigation(url: webView.url)

    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        //        isBeingRedirected = false
        //        invalidateSessionStateData()
        //        webViewDidFinishNavigationPublisher.send()
        //        if isAMPProtectionExtracting { isAMPProtectionExtracting = false }
        //        linkProtection.setMainFrameUrl(nil)
        //        referrerTrimming.onFinishNavigation()
        //        adClickAttributionDetection.onDidFinishNavigation(url: webView.url)
        //        adClickAttributionLogic.onDidFinishNavigation(host: webView.url?.host)
    }

    // never actually gets called
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
        //        hasError = true

        //        isBeingRedirected = false
        //        invalidateSessionStateData()
        //        linkProtection.setMainFrameUrl(nil)
        //        referrerTrimming.onFailedNavigation()
        //        adClickAttributionDetection.onDidFailNavigation()
        //        webViewDidFailNavigationPublisher.send()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
        // TODO: canGoForwardForward is not blocked when in error state
        //        switch error {
        //        case URLError.notConnectedToInternet,
        //             URLError.networkConnectionLost:
        //            guard let failingUrl = error.failingUrl else { break }
        //            NSApp.dependencies.historyCoordinating.markFailedToLoadUrl(failingUrl)
        //        default: break
        //        }
        //
        //        self.error = error
        //        isBeingRedirected = false
        //        linkProtection.setMainFrameUrl(nil)
        //        referrerTrimming.onFailedNavigation()
        //        adClickAttributionDetection.onDidFailNavigation()
        //        webViewDidFailNavigationPublisher.send()
    }

    @available(macOS 11.3, *)
    @objc(webView:navigationAction:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        // don‘t believe the warning
        self.webView(webView, navigationAction: navigationAction, didBecome: download)
    }

    @available(macOS 11.3, *)
    @objc(webView:navigationResponse:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        // don‘t believe the warning
        self.webView(webView, navigationResponse: navigationResponse, didBecome: download)
    }

    func webView(_ webView: WKWebView, didStartProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo) {
        guard frame.isMainFrame else { return }
        //        self.mainFrameLoadState = .provisional
    }

    func webView(_ webView: WKWebView, didCommitLoadWith request: URLRequest, in frame: WKFrameInfo) {
        guard frame.isMainFrame else { return }
        //        self.mainFrameLoadState = .committed
    }

    func webView(_ webView: WKWebView, willPerformClientRedirectTo url: URL, delay: TimeInterval) {
        //        if case .committed = self.mainFrameLoadState {
        //            self.clientRedirectedDuringNavigationURL = url
        //        }
    }

    func webView(_ webView: WKWebView, didFinishLoadWith request: URLRequest, in frame: WKFrameInfo) {
        //        guard frame.isMainFrame else { return }
        //        self.mainFrameLoadState = .finished
        //
        //        StatisticsLoader.shared.refreshRetentionAtb(isSearch: request.url?.isDuckDuckGoSearch == true)
        //
        //        self.currentBackForwardItem = webView.backForwardList.currentItem
    }

    func webView(_ webView: WKWebView, didFailProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error) {
        //        guard frame.isMainFrame else { return }
        //        self.mainFrameLoadState = .finished
        //
        //        self.currentBackForwardItem = webView.backForwardList.currentItem
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        //        navigationEventsSubject.send(.webContentProcessDidTerminate)
        //        Pixel.fire(.debug(event: .webKitDidTerminate))
    }

}

struct FrameHandle: Hashable {
    private let handle: AnyHashable
    init(frame: WKFrameInfo) {
        if frame.isMainFrame {
            self.handle = 0
        } else if let handle = frame.value(forKey: "_handle") as? NSObject {
            self.handle = handle
        } else {
            self.handle = 1
        }
    }
}

// universal download event handlers for Legacy _WKDownload and modern WKDownload
extension NavigationDelegate: WKWebViewDownloadDelegate {

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecomeDownload download: WebKitDownload) {
        //        FileDownloadManager.shared.add(download, delegate: self.delegate, location: .auto, postflight: .none)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload) {
        //        FileDownloadManager.shared.add(download, delegate: self.delegate, location: .auto, postflight: .none)
        //
        //        // Note this can result in tabs being left open, e.g. download button on this page:
        //        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        //        // Safari closes new tabs that were opened and then create a download instantly.
        //        if self.webView.backForwardList.currentItem == nil,
        //           // TODO: replace it with "navigationAction.sourceFrame"?
        // TODO: also close for asana/zoom links
        //           self.parentTab != nil {
        //            DispatchQueue.main.async { [weak delegate=self.delegate] in
        //                delegate?.closeTab(self)
        //            }
        //        }
    }

    func webView(_ webView: WKWebView, contextMenuDidCreate download: WebKitDownload) {
        //        FileDownloadManager.shared.add(download, delegate: self.delegate, location: .auto, postflight: .none)
    }

}



struct LocalFileNavigationPolicyHandler: PartialNavigationPolicyHandler {
    func decidePolicy(for navigationAction: NavigationAction) async -> NavigationActionPolicy? {
        return (navigationAction.request.url?.isFileURL == true) ? .instantAllow : nil
    }
}

//final class LinkProtectionWrapper: PartialNavigationPolicyHandler {
//    private var linkProtection: LinkProtection
//
//    init(privacyManager: PrivacyConfigurationManager, contentBlockingManager: ContentBlockerRulesManager, errorReporting: EventMapping<AMPProtectionDebugEvents>) {
//        linkProtection = LinkProtection(privacyManager: privacyManager, contentBlockingManager: contentBlockingManager, errorReporting: errorReporting)
//
//    }
extension LinkProtection: PartialNavigationPolicyHandler {

    func decidePolicy(for navigationAction: NavigationAction) async -> NavigationActionPolicy? {
        // This check needs to happen before GPC checks. Otherwise the navigation type may be rewritten to `.other`
        // which would skip link rewrites.
        guard case .linkActivated = navigationAction.navigationType else { return nil }

        return nil
        //        return await withCheckedContinuation { continuation in
        //            let willRewriteLink = self
        //            // TODO: context.currentURL is webView.url
        //                .requestTrackingLinkRewrite(initiatingURL: navigationAction.targetFrame?.request.url,
        //                                            navigationAction: navigationAction,
        //                                            onStartExtracting: {
        ////                    if !isRequestingNewTab {
        ////                    self.isAMPProtectionExtracting = true
        ////                    }
        //
        //                }, onFinishExtracting: { // [weak self] in
        ////                    self?.isAMPProtectionExtracting = false
        //
        //                }, onLinkRewrite: { /*[weak self]*/ url, _ in
        ////                    guard let self = self else { return }
        //
        //                    // TODO: error here !isTargetingMainFrame may be not opening new tab but navigating a frame
        ////                    if isRequestingNewTab || !navigationAction.isTargetingMainFrame {
        ////                        self.delegate?.tab(
        ////                            self,
        ////                            requestedNewTabWith: .url(url),
        ////                            selected: shouldSelectNewTab || !navigationAction.isTargetingMainFrame
        ////                        )
        ////                    } else {
        //                        continuation.resume(returning: .redirect(request: .init(url: url)))
        ////                    }
        //
        //                }, policyDecisionHandler: { navigationActionPolicy in
        //                    if navigationActionPolicy == .allow {
        //                        continuation.resume(returning: nil)
        //                    } // else: await for URL in onLinkRewrite
        //                })
        //
        //            if !willRewriteLink {
        //                continuation.resume(returning: nil)
        //            }
        //        }
    }

}

extension ReferrerTrimming: PartialNavigationPolicyHandler {

    func decidePolicy(for navigationAction: NavigationAction) async -> NavigationActionPolicy? {
        return nil
        //        guard navigationAction.isTargetingMainFrame,
        //              !navigationAction.navigationType.isBackForwardNavigation,
        //              let newRequest = trimReferrer(forNavigation: navigationAction,
        //                                            // TODO: webView.url
        //                                            originUrl: navigationAction.targetFrame?.request.url ?? navigationAction.sourceFrame.webView?.url)
        //        else {
        //            return nil
        //        }
        //
        //        return .redirect(request: newRequest)
    }

}



struct NavigationAction {
    private let navigationAction: WKNavigationAction

    /// The type of action that triggered the navigation.
    let navigationType: NavigationType
    var isBackForwardNavigation: Bool {
        //        [.backNavigation, .forwardNavigation].contains(navigationType)
        false
    }

    /// The frame requesting the navigation.
    var sourceFrame: WKFrameInfo { navigationAction.sourceFrame }

    /// The target frame, or nil if this is a new window navigation.
    var targetFrame: WKFrameInfo? { navigationAction.targetFrame }

    /// Indicates whether the target frame is the main frame
    var isTargetingMainFrame: Bool {
        navigationAction.targetFrame?.isMainFrame ?? false
    }

    // The navigation's request.
    var request: URLRequest { navigationAction.request }

    /// The modifier keys that were in effect when the navigation was requested.
    var modifierFlags: NSEvent.ModifierFlags { navigationAction.modifierFlags }

    /// Whether the web content used a download attribute to indicate that this should be downloaded.
    var shouldDownload: Bool {
        if #available(macOS 12, *) {
            return navigationAction.shouldPerformDownload
        } else {
            return navigationAction._shouldPerformDownload
        }
    }

    var isMiddleClick: Bool {
        navigationAction.buttonNumber == 4
    }

    var isUserInitiated: Bool {
        return navigationAction.isUserInitiated
    }

    init(navigationAction: WKNavigationAction, userEntered: Bool, currentBackForwardItem: WKBackForwardListItem?) {
        self.navigationAction = navigationAction
        self.navigationType = .clientRedirect // .backNavigation

    }

}
