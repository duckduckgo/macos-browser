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

final class DistributedNavigationDelegate: NSObject, TabExtension {

    var responders = [NavigationResponder]()
    private var mainFrame: WKFrameInfo?
    private var mainFrameRequest: URLRequest?

    override init() {
        super.init()
        // Fix nullable navigationAction.sourceFrame
        WKNavigationAction.swizzleNonnullSourceFrameFix()
    }

    func attach(to tab: Tab) {
    }

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

// MARK: - WebViewNavigationDelegate
extension DistributedNavigationDelegate: WebViewNavigationDelegate {

    // MARK: Expectaion

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

    @objc(_webView:willPerformClientRedirectToURL:delay:)
    func webView(_ webView: WKWebView, willPerformClientRedirectTo url: URL, delay: TimeInterval) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, willPerformClientRedirectTo: url, delay: delay)
        }
    }

    // MARK: Decide Policy for Navigation Action

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {

        let decisionHandler = { (decision: WKNavigationActionPolicy, preferences: WKWebpagePreferences) in
            if case .allow = decision,
                navigationAction.isTargetingMainFrame {

                self.mainFrame = navigationAction.targetFrame
                self.mainFrameRequest = navigationAction.request
            }
            decisionHandler(decision, preferences)
        }

        var navigationPreferences = NavigationPreferences(userAgent: webView.customUserAgent, preferences: preferences)
        makeAsyncDecision(for: webView) { responder, webView in
            await responder.webView(webView, decidePolicyFor: navigationAction, preferences: &navigationPreferences)
        } completion: { (decision: NavigationActionPolicy) in
            switch decision {
            case .allow:
                navigationPreferences.export(to: preferences)
                webView.customUserAgent = navigationPreferences.userAgent
                decisionHandler(.allow, preferences)
            case .cancel:
                decisionHandler(.cancel, preferences)
            case .download:
                // register the navigationAction for legacy _WKDownload to be called back on the Navigation Delegate
                // further download will be passed to webView:navigationAction:didBecomeDownload:
                decisionHandler(.download(navigationAction), preferences)
            case .redirect(request: let request):
                decisionHandler(.cancel, preferences)
                // TODO: If navigation is committed only!
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
//      referrerTrimming
//
        // GPC
//
        // Download
//
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
        // httpsUpgrade
        // prepare for content blocking
//
//
//        willPerformNavigationAction(navigationAction)
//
//        return .allow
    }

    // MARK: Navigation

    @MainActor
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

//    private func willPerformNavigationAction(_ navigationAction: WKNavigationAction) {
//        guard navigationAction.isTargetingMainFrame else { return }
//
//        self.externalSchemeOpenedPerPageLoad = false
//        delegate?.tabWillStartNavigation(self, isUserInitiated: navigationAction.isUserInitiated)
//    }

    @MainActor
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        makeAsyncDecision(for: webView) { responder, webView in
            await responder.webView(webView, decidePolicyFor: navigationResponse)
        } completion: { decision in
            decisionHandler(decision)
        } defaultHandler: {
            decisionHandler(.allow)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
        // initial navigation happens without decidePolicyForNavigationAction
        // TODO: Does new window navigation ask for permission?
        guard let mainFrame = mainFrame, let request = mainFrameRequest else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didStartNavigationWith: request, in: mainFrame)
        }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didStart: navigation, with: request)
        }

//        delegate?.tabDidStartNavigation(self)
//
//        // Unnecessary assignment triggers publishing
//        if error != nil { error = nil }
//
//        invalidateSessionStateData()
    }

    @objc(_webView:didStartProvisionalLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didStartProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo) {
        // main frame events are handled in didStartProvisionalNavigation:
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
    }

    @MainActor
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, didCommitNavigationWith: request, in: mainFrame)
        }
        notifyResponders(with: webView) { responder, webView, _, request in
            responder.webView(webView, didCommit: navigation, with: request)
        }

        //        webViewDidCommitNavigationPublisher.send()
    }

    @MainActor
    func webView(_ webView: WKWebView, backForwardListItemAdded itemAdded: WKBackForwardListItem, itemsRemoved: [WKBackForwardListItem]) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, backForwardListItemAdded: itemAdded, itemsRemoved: itemsRemoved)
        }
    }

    @objc(_webView:didCommitLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didCommitLoadWith request: URLRequest, in frame: WKFrameInfo) {
        // main frame events are handled in didCommitNavigation:
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didCommitNavigationWith: request, in: frame)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, didFinishNavigationWith: request, in: mainFrame)
        }
        notifyResponders(with: webView) { responder, webView, _, request in
            responder.webView(webView, didFinish: navigation, with: request)
        }

//        invalidateSessionStateData()
    }

    @objc(_webView:didFinishLoadWithRequest:inFrame:)
    func webView(_ webView: WKWebView, didFinishLoadWith request: URLRequest, in frame: WKFrameInfo) {
        // main frame events are handled in didCommitNavigation:
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, didFinishNavigationWith: request, in: frame)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, navigationWith: request, in: mainFrame, didFailWith: error)
        }
        notifyResponders(with: webView) { responder, webView, _, request in
            responder.webView(webView, navigation: navigation, with: request, didFailWith: error)
        }

        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
        //        hasError = true

//        invalidateSessionStateData()
//        webViewDidFailNavigationPublisher.send()
    }

    @objc(_webView:didFailLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView, didFailLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error) {
        // main frame events are handled in didFailNavigation:
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, navigationWith: request, in: frame, didFailWith: error)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
        notifyResponders(with: webView) { responder, webView, mainFrame, request in
            responder.webView(webView, navigationWith: request, in: mainFrame, didFailWith: error)
        }
        notifyResponders(with: webView) { responder, webView, _, request in
            responder.webView(webView, navigation: navigation, with: request, didFailWith: error)
        }

//        self.error = error
//        webViewDidFailNavigationPublisher.send()
    }

    @objc(_webView:didFailProvisionalLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView, didFailProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error) {
        // main frame events are handled in didFailProvisionalNavigation:
        guard !frame.isMainFrame else { return }
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, navigationWith: request, in: frame, didFailWith: error)
        }
    }

//_webView:navigationDidFinishDocumentLoad:
//_webView:renderingProgressDidChange:
//_webView:contentRuleListWithIdentifier:performedAction:forURL:

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
        Pixel.fire(.debug(event: .webKitDidTerminate))
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
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, navigationResponse: navigationResponse, didBecome: download)
        }
    }

    func webView(_ webView: WKWebView, contextMenuDidCreateDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.webView(webView, contextMenuDidCreate: download)
        }
    }

}
