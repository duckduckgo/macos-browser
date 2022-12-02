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
import os.log

fileprivate protocol AnyResponderRef {
    var responder: NavigationResponder? { get }
    var responderType: String { get }
}
extension DistributedNavigationDelegate.WeakResponderRef where T: AnyObject {
    convenience init(_ responder: T) {
        self.init(responder: responder)
    }
}

final class DistributedNavigationDelegate: NSObject {
    fileprivate enum ResponderRef<T: NavigationResponder>: AnyResponderRef {
        case weak(WeakResponderRef<T>)
        case strong(T)
        var responder: NavigationResponder? {
            switch self {
            case .weak(let ref): return ref.responder
            case .strong(let responder): return responder
            }
        }
        var responderType: String {
            "\(T.self)"
        }
    }
    struct ResponderRefMaker {
        fileprivate let ref: AnyResponderRef
        private init(_ ref: AnyResponderRef) {
            self.ref = ref
        }
        static func `weak`(_ responder: (some NavigationResponder & AnyObject)) -> ResponderRefMaker {
            return .init(ResponderRef.weak(WeakResponderRef(responder)))
        }
        static func `weak`(nullable responder: (some NavigationResponder & AnyObject)?) -> ResponderRefMaker? {
            guard let responder = responder else { return nil }
            return .init(ResponderRef.weak(WeakResponderRef(responder)))
        }
        static func `strong`(_ responder: some NavigationResponder & AnyObject) -> ResponderRefMaker {
            return .init(ResponderRef.strong(responder))
        }
        static func `strong`(nulable responder: (some NavigationResponder & AnyObject)?) -> ResponderRefMaker? {
            guard let responder = responder else { return nil }
            return .init(ResponderRef.strong(responder))
        }
        static func `struct`(_ responder: some NavigationResponder) -> ResponderRefMaker {
            assert(Mirror(reflecting: responder).displayStyle == .struct, "\(type(of: responder)) is not a struct")
            return .init(ResponderRef.strong(responder))
        }
        static func `struct`(nullable responder: NavigationResponder?) -> ResponderRefMaker? {
            guard let responder = responder else { return nil }
            return .struct(responder)
        }
    }
    fileprivate class WeakResponderRef<T: NavigationResponder> {
        weak var responder: (NavigationResponder & AnyObject)?
        init(responder: (NavigationResponder & AnyObject)?) {
            self.responder = responder
        }
    }

    private var responderRefs: [AnyResponderRef] = []
    var responders: [NavigationResponder] {
        return responderRefs.enumerated().reversed().compactMap { (idx, ref) in
            guard let responder = ref.responder else {
                responderRefs.remove(at: idx)
                return nil
            }
            return responder
        }.reversed()
    }
    func setResponders(_ refs: ResponderRefMaker?...) {
        let nonnullRefs = refs.compactMap { $0 }
        responderRefs = nonnullRefs.map(\.ref)
        assert(responders.count == nonnullRefs.count, "Some NavigationResponders were released right creation: " + "\(Set(nonnullRefs.map(\.ref.responderType)).subtracting(responders.map { "\(type(of: $0))" }))")
    }

    private var expectedNavigation: NavigationAction?
    var currentNavigation: Navigation?

    private let logger: OSLog

    init(logger: OSLog) {
        self.logger = logger
    }

    func notifyResponders<T>(with optional: T?, do closure: (NavigationResponder, T) -> Void) {
        guard let arg = optional else {
            assertionFailure("Passed Optional<\(T.self)> is nil")
            return
        }
        for responder in responders {
            closure(responder, arg)
        }
    }

    func makeAsyncDecision<T>(decide: @escaping (NavigationResponder) async -> T?,
                              completion: @escaping (T) -> Void,
                              defaultHandler: @escaping () -> Void) {
        Task { @MainActor in
            let result = await { () -> T? in
                for responder in responders {
                    guard let result = await decide(responder) else { continue }
                    return result
                }
                return nil
            }()
            if let result {
                completion(result)
            } else {
                defaultHandler()
            }
        }
    }

}

// MARK: - WebViewNavigationDelegate
extension DistributedNavigationDelegate: WKNavigationDelegate {

    // MARK: Policy making

    func webView(_ webView: WKWebView, decidePolicyFor wkNavigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {

        var navigationType: NavigationType?
        // TODO: receive state in currentNavigation
        if wkNavigationAction.targetFrame?.isMainFrame == true,
           case .other = wkNavigationAction.navigationType,
           !wkNavigationAction.request.isUserInitiated,
           !wkNavigationAction.isUserInitiated,
           self.currentNavigation != nil,
           let awaitedRedirect = currentNavigation!.state.awaitedRedirect,
           (awaitedRedirect.url == nil || awaitedRedirect.url == wkNavigationAction.request.url) {

            // we are in client-redirect state
            os_log("%s received client redirect to: %s", log: logger, type: .default, currentNavigation!.debugDescription, wkNavigationAction.request.url!.absoluteString)
            self.currentNavigation!.redirected()
            navigationType = .redirect(type: awaitedRedirect.type, navigation: self.currentNavigation!)
        }
        let navigationAction = NavigationAction(wkNavigationAction, navigationType: navigationType)
        os_log("%s decidePolicyFor: %s", log: logger, type: .default, webView.debugDescription, navigationAction.debugDescription)

        let decisionHandler = { (decision: WKNavigationActionPolicy, navigationPreferences: NavigationPreferences) in
            if case .allow = decision {
                if navigationAction.isForMainFrame {
                    webView.customUserAgent = navigationPreferences.userAgent
                    self.expectedNavigation = navigationAction
                }
                navigationPreferences.export(to: preferences)
                os_log("%s will start navigation: %s", log: self.logger, type: .default, webView.debugDescription, navigationAction.debugDescription)
            } // TODO: else: cancel if matching current navigation
            decisionHandler(decision, preferences)
        }

        var preferences = NavigationPreferences(userAgent: webView.customUserAgent, preferences: preferences)

        makeAsyncDecision { responder in
            guard !Task.isCancelled else {
                // TODO: log
                return .allow
            }
            guard let decision = await responder.decidePolicy(for: navigationAction, preferences: &preferences) else { return .next }
            os_log("%s: %s decision: %s", log: self.logger, type: .default, navigationAction.debugDescription, "\(type(of: responder))", decision.debugDescription)
            return decision
        } completion: { (decision: NavigationActionPolicy) in
            switch decision {
            case .allow:
                decisionHandler(.allow, preferences)
            case .cancel:
                decisionHandler(.cancel, preferences)
            case .download:
                // register the navigationAction for legacy _WKDownload to be called back on the Navigation Delegate
                // further download will be passed to webView:navigationAction:didBecomeDownload:
                decisionHandler(.download(wkNavigationAction), preferences)
            case .redirect(request: let request):
                decisionHandler(.cancel, preferences)
                if navigationAction.isForMainFrame {
                    self.currentNavigation?.willRedirect(type: .developer, url: request.url)
                }
                // TODO: notifyResponders(with: <#T##T?#>) { <#NavigationResponder#>, <#T#> in
//                    responder.redirect(to)
//                }
//                self.delegate?.redirect(navigationAction, to: request)
            case .retarget(in: let windowKind):
                decisionHandler(.cancel, preferences)
                if navigationAction.isForMainFrame {
                    // TODO: willCancel?
                    self.currentNavigation?.willRedirect(type: .developer, url: navigationAction.url)
                }
//                self.delegate?.retarget(navigationAction, to: windowKind)
            }
        } defaultHandler: {
            decisionHandler(.allow, preferences)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        os_log("%s didReceive: %s", log: logger, type: .default, webView.debugDescription, String(describing: challenge))

        makeAsyncDecision { responder in
            guard let decision = await responder.didReceive(challenge) else { return .next }
            os_log("%s: %s decision: %s", log: self.logger, type: .default, String(describing: challenge), "\(type(of: responder))", String(describing: decision.dispositionAndCredential.0))
            return decision
        } completion: { (decision: AuthChallengeDisposition) in
            let (disposition, credential) = decision.dispositionAndCredential
            os_log("%s didReceive: %s", log: self.logger, type: .default, webView.debugDescription, String(describing: challenge))
            completionHandler(disposition, credential)
        } defaultHandler: {
            os_log("%s: performDefaultHandling", log: self.logger, type: .default, String(describing: challenge))
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

    // MARK: Navigation

    @MainActor
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation) {
        defer {
            expectedNavigation = nil
        }
        if let expectedNavigation {
            self.currentNavigation = Navigation(navigation: navigation, navigationAction: expectedNavigation)
        } else {
            guard let url = webView.url else {
                assertionFailure("didStartProvisionalNavigation without URL")
                return
            }
            // session restoration happens without NavigationAction
            // TODO: Set unapprovedNavigationAction in decidePolicyFor, pass here and cancel in decidePolicyFor
            self.currentNavigation = Navigation(navigation: navigation, navigationAction: .sessionRestoreNavigation(url: url))
        }
        os_log("%s didStart%s: %s", log: self.logger, type: .default, webView.debugDescription, expectedNavigation == nil ? " session restoration" : "", currentNavigation!.debugDescription)

        // TODO: Does new window navigation ask for permission?
        notifyResponders(with: currentNavigation) { responder, navigation in
            responder.didStart(navigation)
        }

        //        invalidateSessionStateData()
    }

    @MainActor
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation) {
        // TODO: modify currentNavigation from expectedNavigationAction
        os_log("%s didReceiveServerRedirect for: %s", log: self.logger, type: .default, webView.debugDescription, navigation.description) // TODO: currentNavigation!.debugDescription)
    }

    @MainActor
    func webView(_ webView: WKWebView, decidePolicyFor wkNavigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let navigationResponse = NavigationResponse(navigationResponse: wkNavigationResponse, navigation: self.currentNavigation)
        os_log("%s decidePolicyFor: %s", log: logger, type: .default, webView.debugDescription, navigationResponse.debugDescription)

        makeAsyncDecision { responder -> NavigationResponsePolicy? in
            guard let decision = await responder.decidePolicy(for: navigationResponse) else { return .next }
            os_log("%s: %s decision: %s", log: self.logger, type: .default, navigationResponse.debugDescription, "\(type(of: responder))", "\(decision)")
            return decision
        } completion: { (decision: NavigationResponsePolicy) in
            switch decision {
            case .allow:
                decisionHandler(.allow)
            case .cancel:
                decisionHandler(.cancel)
            case .download:
                // register the navigationResponse for legacy _WKDownload to be called back on the Tab
                // further download will be passed to webView:navigationResponse:didBecomeDownload:
                decisionHandler(.download(wkNavigationResponse, using: webView))
            }
        } defaultHandler: {
            decisionHandler(.allow)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation) {
        currentNavigation?.committed()
        os_log("%s didCommit: %s", log: self.logger, type: .default, webView.debugDescription, currentNavigation!.debugDescription)

        notifyResponders(with: currentNavigation?.ifMatches(navigation)) { responder, navigation in
            responder.didCommit(navigation)
        }
    }

    @MainActor
    @objc(_webView:willPerformClientRedirectToURL:delay:)
    func webView(_ webView: WKWebView, willPerformClientRedirectToURL url: URL, delay: TimeInterval) {
        os_log("%s willPerformClientRedirect to: %s", log: self.logger, type: .default, webView.debugDescription, url.absoluteString)
        currentNavigation?.willRedirect(type: .client, url: url)
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        // TODO: only call if last type is not redirect
        self.currentNavigation?.receivedDidFinish()
        guard let currentNavigation = currentNavigation else {
            assertionFailure("Unexpected didFinishNavigation")
            return
        }
        os_log("%s did finish navigation or received client redirect: %s", log: self.logger, type: .default, webView.debugDescription, currentNavigation.debugDescription)

        notifyResponders(with: currentNavigation) { responder, navigation in
            responder.navigationDidFinishOrReceivedClientRedirect(navigation)
        }

        // Shortly after receiving webView:didFinishNavigation: a client redirect navigation may start
        // it happens on the same WebKit RunLop pass (before the Dispatch happens)
        DispatchQueue.main.async { [weak self, currentNavigation] in
            self?.reallyFinishNavigation(currentNavigation, webView: webView)
        }

//        invalidateSessionStateData()
    }

    @MainActor
    private func reallyFinishNavigation(_ navigation: Navigation, webView: WKWebView) {
        // TODO: log
        guard self.currentNavigation == navigation else { return }
        self.currentNavigation?.finished()
        os_log("%s did finish: %s", log: self.logger, type: .default, webView.debugDescription, currentNavigation!.debugDescription)
        defer {
            self.currentNavigation = nil
        }

        // TODO: make sure it‘s finished
        notifyResponders(with: currentNavigation) { responder, navigation in
            responder.navigationDidFinish(navigation)
        }
    }

    @MainActor
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
        let error = error as? WKError ?? WKError(_nsError: error as NSError)
        currentNavigation?.didFail(with: error)
        os_log("%s did fail %s with: %s", log: self.logger, type: .default, webView.debugDescription, currentNavigation!.debugDescription, error.localizedDescription)
        defer {
            self.currentNavigation = nil
        }

        notifyResponders(with: currentNavigation) { responder, navigation in
            responder.navigation(navigation, didFailWith: error)
        }

        // Failing not captured. Seems the method is called after calling the webview's method goBack()
        // https://app.asana.com/0/1199230911884351/1200381133504356/f
        //        hasError = true

//        invalidateSessionStateData()
//        webViewDidFailNavigationPublisher.send()

//        webView.evaluateJavaScript("""
//            document.open("text/html", "replace");
//            document.write(newText);
//            document.close();
//        """)

    }

    @MainActor
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation, withError error: Error) {
        let error = error as? WKError ?? WKError(_nsError: error as NSError)
        currentNavigation?.didFail(with: error)
        os_log("%s did fail provisional navigation %s with: %s", log: self.logger, type: .default, webView.debugDescription, currentNavigation!.debugDescription, error.localizedDescription)
        defer {
            self.currentNavigation = nil
        }

        notifyResponders(with: currentNavigation) { responder, navigation in
            responder.navigation(navigation, didFailWith: error)
        }

//        self.error = error
//        webViewDidFailNavigationPublisher.send()
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

    @MainActor
    @available(macOS 11.3, *)
    @objc(_webView:contextMenuDidCreateDownload:)
    func webView(_ webView: WKWebView, contextMenuDidCreate download: WKDownload) {
        self.webView(webView, contextMenuDidCreateDownload: download)
    }

    @MainActor
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        currentNavigation?.didFail(with: WKError(WKError.Code.webContentProcessTerminated))
        os_log("%s process did terminate; current navigation: %s", log: self.logger, type: .default, webView.debugDescription, currentNavigation?.debugDescription ?? "<nil>")
        defer {
            self.currentNavigation = nil
        }

        notifyResponders(with: webView) { responder, webView in
            responder.webContentProcessDidTerminate(currentNavigation: currentNavigation)
        }
        Pixel.fire(.debug(event: .webKitDidTerminate))
    }

}

// universal download event handlers for Legacy _WKDownload and modern WKDownload
extension DistributedNavigationDelegate: WKWebViewDownloadDelegate {

    // TODO: Log, reset currentNavigation
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecomeDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.navigationAction(NavigationAction(navigationAction), didBecome: download)
        }
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecomeDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.navigationResponse(NavigationResponse(navigationResponse: navigationResponse, navigation: currentNavigation), didBecome: download)
        }
    }

    func webView(_ webView: WKWebView, contextMenuDidCreateDownload download: WebKitDownload) {
        notifyResponders(with: webView) { responder, webView in
            responder.contextMenuDidCreateDownload(download)
        }
    }

}
