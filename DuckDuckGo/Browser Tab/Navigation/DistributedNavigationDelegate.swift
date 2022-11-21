//
//  DistributedNavigationDelegate.swift
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

final class DistributedNavigationDelegate: NSObject {

    var responders = [NavigationResponder]()
    private var mainFrame: WKFrameInfo?
    private var mainFrameRequest: URLRequest?

    func notifyResponders(with webView: WKWebView, do closure: (NavigationResponder, WebView) -> Void) {
        guard let webView = webView as? WebView else {
            assertionFailure("Expected WebView subclass")
            return
        }
        for responder in responders {
            closure(responder, webView)
        }
    }

    func notifyResponders(with webView: WKWebView, do closure: (NavigationResponder, WebView, WKFrameInfo, URLRequest) -> Void) {
        guard let mainFrame = mainFrame,
              let mainFrameRequest = mainFrameRequest
        else {
            assertionFailure("main frame not present")
            return
        }
        notifyResponders(with: webView) { closure($0, $1, mainFrame, mainFrameRequest) }
    }

    func makeAsyncDecision<T>(for webView: WKWebView,
                              decide: @escaping (NavigationResponder, WebView) async -> T?,
                              completion: @escaping (T) -> Void,
                              defaultHandler: @escaping () -> Void) {
        guard let webView = webView as? WebView else {
            assertionFailure("Expected WebView subclass")
            defaultHandler()
            return
        }
        Task { @MainActor in
            let result = await { () -> T? in
                for responder in responders {
                    guard let result = await decide(responder, webView) else { continue }
                    return result
                }
                return nil
            }()
            result.map(completion) ?? defaultHandler()
        }
    }

}

extension DistributedNavigationDelegate: WebViewNavigationDelegate {

    func webView(_ webView: WebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, willStartNavigation: navigation, with: request)
        }
    }

    func webView(_ webView: WebView, willStartReloadNavigation navigation: WKNavigation?) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, willStartReloadNavigation: navigation)
        }
    }

    func webView(_ webView: WebView, willStartUserInitiatedNavigation navigation: WKNavigation?, to backForwardListItem: WKBackForwardListItem?) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, willStartUserInitiatedNavigation: navigation, to: backForwardListItem)
        }
    }

    func webView(_ webView: WebView, willRequestNewWebViewFor url: URL, inTargetNamed target: String?, windowFeatures: WindowFeatures?) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, willRequestNewWebViewFor: url, inTargetNamed: target.map(TargetWindowName.init), windowFeatures: windowFeatures)
        }
    }

    func webViewWillRestoreSessionState(_ webView: WebView) {
        notifyResponders(with: webView) { responder, webView in
            responder.webViewWillRestoreSessionState(webView)
        }
    }

    @objc(_webViewDidEndNavigationGesture:withNavigationToBackForwardListItem:)
    func webView(_ webView: WKWebView, didEndNavigationGestureWithNavigationTo backForwardListItem: WKBackForwardListItem?) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didEndNavigationGestureWithNavigationTo: backForwardListItem)
        }
    }

    @objc(_webView:willGoToBackForwardListItem:inPageCache:)
    func webView(_ webView: WKWebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool) {
        // called twice: before _webViewDidEndNavigationGesture: and after decidePolicyForNavigationAction:
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, willGoTo: backForwardListItem, inPageCache: inPageCache)
        }
    }

    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        makeAsyncDecision(for: webView) { responder, webView in
            await responder.webView(webView, didReceive: challenge)
        } completion: { disposition in
            disposition.pass(to: completionHandler)
        } defaultHandler: {
            completionHandler(.performDefaultHandling, nil)
        }

//
//        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
//           let delegate = delegate {
//            delegate.tab(self, requestedBasicAuthenticationChallengeWith: challenge.protectionSpace, completionHandler: completionHandler)
//            return
//        }
//
//        completionHandler(.performDefaultHandling, nil)
//        if let host = webView.url?.host, let serverTrust = challenge.protectionSpace.serverTrust, host == challenge.protectionSpace.host {
//            self.serverTrust = ServerTrust(host: host, secTrust: serverTrust)
//        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didReceiveServerRedirectFor: navigation)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, didCommitNavigationWith: request, in: mainFrame)
        }

//        isBeingRedirected = false
//        if content.isUrl, let url = webView.url {
//            addVisit(of: url)
//        }
//        webViewDidCommitNavigationPublisher.send()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {

        let decisionHandler = { (decision: WKNavigationActionPolicy, preferences: WKWebpagePreferences) in
            if case .allow = decision,
                navigationAction.isTargetingMainFrame {

                self.mainFrame = navigationAction.targetFrame
                self.mainFrameRequest = navigationAction.request
            }
            decisionHandler(decision, preferences)
        }

        makeAsyncDecision(for: webView) { responder, webView in
            await responder.webView(webView, decidePolicyFor: navigationAction, preferences: preferences)
        } completion: { (decision: NavigationActionPolicy) in
            switch decision {
            case .allow(userAgent: let userAgent, contentMode: let contentMode, javaScriptEnabled: let jsEnabled):
                // TODO: make this inout passed throughout all the handlers and return in the end?, maybe extend with some more properties or subclass
                let preferences = WKWebpagePreferences()
                preferences.preferredContentMode = contentMode
                if #available(macOS 11.0, *) {
                    preferences.allowsContentJavaScript = jsEnabled
                } else {
                    webView.configuration.preferences.javaScriptEnabled = jsEnabled
                }
                webView.customUserAgent = userAgent
                decisionHandler(.allow, preferences)
            case .cancel:
                decisionHandler(.cancel, preferences)
            case .download:
                decisionHandler(.download(navigationAction), preferences)
            case .redirect(request: let request):
                decisionHandler(.cancel, preferences)
                webView.replaceLocation(with: request.url!, in: navigationAction.targetFrame ?? navigationAction.sourceFrame)
            case .retarget(in: let windowFeatures):
                decisionHandler(.cancel, preferences)
                guard let url = navigationAction.request.url else { return }
                webView.load(url, in: .blank, windowFeatures: windowFeatures)
            }
        } defaultHandler: {
            decisionHandler(.allow, preferences)
        }

//
//
//        // This check needs to happen before GPC checks. Otherwise the navigation type may be rewritten to `.other`
//        // which would skip link rewrites.
//        if navigationAction.navigationType != .backForward {
//            let navigationActionPolicy = await linkProtection
//                .requestTrackingLinkRewrite(
//                    initiatingURL: webView.url,
//                    navigationAction: navigationAction,
//                    onStartExtracting: { if !isRequestingNewTab { isAMPProtectionExtracting = true }},
//                    onFinishExtracting: { [weak self] in self?.isAMPProtectionExtracting = false },
//                    onLinkRewrite: { [weak self] url, _ in
//                        guard let self = self else { return }
//                        if isRequestingNewTab || !navigationAction.isTargetingMainFrame {
//                            self.delegate?.tab(
//                                self,
//                                requestedNewTabWith: .url(url),
//                                selected: shouldSelectNewTab || !navigationAction.isTargetingMainFrame
//                            )
//                        } else {
//                            webView.load(url)
//                        }
//                    })
//            if let navigationActionPolicy = navigationActionPolicy, navigationActionPolicy == .cancel {
//                return navigationActionPolicy
//            }
//        }
//
//        webView.customUserAgent = UserAgent.for(navigationAction.request.url)
//
//                                                if navigationAction.isTargetingMainFrame, navigationAction.request.mainDocumentURL?.host != lastUpgradedURL?.host {
//            lastUpgradedURL = nil
//        }
//
//
//        if navigationAction.isTargetingMainFrame, navigationAction.navigationType != .backForward {
//            if let newRequest = referrerTrimming.trimReferrer(forNavigation: navigationAction,
//                                                              originUrl: webView.url ?? navigationAction.sourceFrame.webView?.url) {
//                if isRequestingNewTab {
//                    delegate?.tab(
//                        self,
//                        requestedNewTabWith: newRequest.url.map { .contentFromURL($0) } ?? .none,
//                        selected: shouldSelectNewTab)
//                } else {
//                    _ = webView.load(newRequest)
//                }
//                return .cancel
//            }
//        }
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
//            self.delegate?.tab(self, requestedOpenExternalURL: url, forUserEnteredURL: userEnteredUrl)
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
//        if navigationAction.isTargetingMainFrame,
//           navigationAction.request.url?.isDuckDuckGo == true,
//           navigationAction.request.value(forHTTPHeaderField: Constants.ddgClientHeaderKey) == nil,
//           navigationAction.navigationType != .backForward {
//
//            var request = navigationAction.request
//            request.setValue(Constants.ddgClientHeaderValue, forHTTPHeaderField: Constants.ddgClientHeaderKey)
//            _ = webView.load(request)
//            return .cancel
//        }
//
//        toggleFBProtection(for: url)
//        willPerformNavigationAction(navigationAction)
//
//        return .allow
    }

//    private func urlDidUpgrade(_ upgradedURL: URL,
//                               navigationAction: WKNavigationAction) {
//        lastUpgradedURL = upgradedURL
//        invalidateBackItemIfNeeded(for: navigationAction)
//        webView.load(upgradedURL)
//        setConnectionUpgradedTo(upgradedURL, navigationAction: navigationAction)
//    }

//    @MainActor
//    private func prepareForContentBlocking() async {
        // Ensure Content Blocking Assets (WKContentRuleList&UserScripts) are installed
//        if !userContentController.contentBlockingAssetsInstalled {
//            Dependencies.cbaTimeReporter?.tabWillWaitForRulesCompilation(self.instrumentation.currentTabIdentifier)
//            await userContentController.awaitContentBlockingAssetsInstalled()
//            Dependencies.cbaTimeReporter?.reportWaitTimeForTabFinishedWaitingForRules(self.instrumentation.currentTabIdentifier)
//        } else {
//            Dependencies.cbaTimeReporter?.reportNavigationDidNotWaitForRules()
//        }
//    }

//    private func toggleFBProtection(for url: URL) {
        // Enable/disable FBProtection only after UserScripts are installed (awaitContentBlockingAssetsInstalled)
//        let privacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
//
//        let featureEnabled = privacyConfiguration.isFeature(.clickToPlay, enabledForDomain: url.host)
//        setFBProtection(enabled: featureEnabled)
//    }

//    private func willPerformNavigationAction(_ navigationAction: WKNavigationAction) {
//        guard navigationAction.isTargetingMainFrame else { return }
//
//        self.externalSchemeOpenedPerPageLoad = false
//        delegate?.tabWillStartNavigation(self, isUserInitiated: navigationAction.isUserInitiated)
//    }

//    private func invalidateBackItemIfNeeded(for navigationAction: WKNavigationAction) {
//        guard let url = navigationAction.request.url,
//              url == self.clientRedirectedDuringNavigationURL
//        else { return }
//
//        // Cancelled & Upgraded Client Redirect URL leaves wrong backForwardList record
//        // https://app.asana.com/0/inbox/1199237043628108/1201280322539473/1201353436736961
//        self.webView.goBack()
//        self.webView.frozenCanGoBack = self.webView.canGoBack
//        self.webView.frozenCanGoForward = false
//    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        makeAsyncDecision(for: webView) { responder, webView in
            await responder.webView(webView, decidePolicyFor: navigationResponse)
        } completion: { decision in
            decisionHandler(decision)
        } defaultHandler: {
            decisionHandler(.allow)
        }

//        userEnteredUrl = false // subsequent requests will be navigations
//
        
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
//        if navigationResponse.response.isSuccessfulHTTPURLResponse {
//                // register the navigationResponse for legacy _WKDownload to be called back on the Tab
//                // further download will be passed to webView:navigationResponse:didBecomeDownload:
//                return .download(navigationResponse, using: webView)
//            }
//        }
//
//        return .allow
    }

    @MainActor
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
        // initial navigation happens without decidePolicyForNavigationAction
        // TODO: Does new window navigation ask for permission?
        guard let mainFrame = mainFrame, let request = mainFrameRequest else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didStartNavigationWith: request, in: mainFrame)
        }

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
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, didFinishNavigationWith: request, in: mainFrame)
        }

//        isBeingRedirected = false
//        invalidateSessionStateData()
//        webViewDidFinishNavigationPublisher.send()
//        if isAMPProtectionExtracting { isAMPProtectionExtracting = false }
//        linkProtection.setMainFrameUrl(nil)
//        referrerTrimming.onFinishNavigation()
    }

    @MainActor
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, navigationWith: request, in: mainFrame, didFailWith: error)
        }

        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
        //        hasError = true

//        isBeingRedirected = false
//        invalidateSessionStateData()
//        linkProtection.setMainFrameUrl(nil)
//        referrerTrimming.onFailedNavigation()
//        webViewDidFailNavigationPublisher.send()
    }

    @MainActor
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, navigationWith: request, in: mainFrame, didFailWith: error)
        }

//        switch error {
//        case URLError.notConnectedToInternet,
//            URLError.networkConnectionLost:
//            guard let failingUrl = error.failingUrl else { break }
//            Dependencies.historyCoordinating.markFailedToLoadUrl(failingUrl)
//        default: break
//        }
//
//        self.error = error
//        isBeingRedirected = false
//        linkProtection.setMainFrameUrl(nil)
//        referrerTrimming.onFailedNavigation()
//        webViewDidFailNavigationPublisher.send()
    }

    @objc(_webView:willPerformClientRedirectToURL:delay:)
    func webView(_ webView: WKWebView, willPerformClientRedirectTo url: URL, delay: TimeInterval) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, willPerformClientRedirectTo: url, delay: delay)
        }
        //        if case .committed = self.mainFrameLoadState {
        //            self.clientRedirectedDuringNavigationURL = url
        //        }
    }
//_webView:navigationDidFinishDocumentLoad:
//_webView:renderingProgressDidChange:
//_webView:contentRuleListWithIdentifier:performedAction:forURL:
    @objc(_webView:didStartProvisionalLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didStartProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo) {
        guard !frame.isMainFrame
                || mainFrame == nil // initial navigation happens without decidePolicyForNavigationAction
        else { return }
        if frame.isMainFrame {
            self.mainFrame = frame
            self.mainFrameRequest = request
        }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didStartNavigationWith: request, in: frame)
        }
//        self.mainFrameLoadState = .provisional
    }

    @objc(_webView:didCommitLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didCommitLoadWith request: URLRequest, in frame: WKFrameInfo) {
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didCommitNavigationWith: request, in: frame)
        }
//        guard frame.isMainFrame else { return }
//        self.mainFrameLoadState = .committed
    }

    @objc(_webView:didFinishLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didFinishLoadWith request: URLRequest, in frame: WKFrameInfo) {
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didFinishNavigationWith: request, in: frame)
        }
//        StatisticsLoader.shared.refreshRetentionAtb(isSearch: request.url?.isDuckDuckGoSearch == true)
    }

    @objc(_webView:didFailLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView, didFailLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error) {
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, navigationWith: request, in: frame, didFailWith: error)
        }
    }

    @objc(_webView:didFailProvisionalLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView, didFailProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error) {
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, navigationWith: request, in: frame, didFailWith: error)
        }
    }

    @MainActor
    @available(macOS 11.3, *)
    @objc(webView:navigationAction:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        self.webView(webView, navigationAction: navigationAction, didBecomeDownload: download)
    }

    @MainActor
    @available(macOS 11.3, *)
    @objc(webView:navigationResponse:didBecomeDownload:)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        self.webView(webView, navigationResponse: navigationResponse, didBecomeDownload: download)
    }

    @available(macOS 11.3, *)
    @objc(_webView:contextMenuDidCreateDownload:)
    func webView(_ webView: WKWebView, contextMenuDidCreate download: WKDownload) {
        self.webView(webView, contextMenuDidCreateDownload: download)
    }

    @MainActor
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, webContentProcessDidTerminateWith: nil)
        }
//        Pixel.fire(.debug(event: .webKitDidTerminate))
    }

    @objc(_webView:webContentProcessDidTerminateWithReason:)
    func webView(_ webView: WKWebView, webContentProcessDidTerminateWith reason: Int) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, webContentProcessDidTerminateWith: WebProcessTerminationReason(rawValue: reason))
        }
    }

}
// universal download event handlers for Legacy _WKDownload and modern WKDownload
extension DistributedNavigationDelegate: WKWebViewDownloadDelegate {

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecomeDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, navigationAction: navigationAction, didBecome: download)
        }

//        FileDownloadManager.shared.add(download, delegate: self.delegate, location: .auto, postflight: .none)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, navigationResponse: navigationResponse, didBecome: download)
        }
        
//        FileDownloadManager.shared.add(download, delegate: self.delegate, location: .auto, postflight: .none)
//
//        // Note this can result in tabs being left open, e.g. download button on this page:
//        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
//        // Safari closes new tabs that were opened and then create a download instantly.
//        if self.webView.backForwardList.currentItem == nil,
//           self.parentTab != nil {
//            DispatchQueue.main.async { [weak delegate=self.delegate] in
//                delegate?.closeTab(self)
//            }
//        }
    }

    func webView(_ webView: WKWebView, contextMenuDidCreateDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, contextMenuDidCreate: download)
        }
    }

}

extension Array where Element == NavigationResponder {
    mutating func set(_ responders: NavigationResponder?...) {
        self = responders.compactMap { $0 }
    }
}
