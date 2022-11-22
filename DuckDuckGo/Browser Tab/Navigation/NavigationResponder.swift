//
//  NavigationResponder.swift
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

enum AuthChallengeDisposition {
    /// Use the specified credential
    case useCredential(URLCredential?)
    /// The entire request will be canceled
    case cancelAuthenticationChallenge
    /// This challenge is rejected and the next authentication protection space should be tried
    case rejectProtectionSpace

    func pass(to decisionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        switch self {
        case .useCredential(let credential):
            decisionHandler(.useCredential, credential)
        case .cancelAuthenticationChallenge:
            decisionHandler(.cancelAuthenticationChallenge, nil)
        case .rejectProtectionSpace:
            decisionHandler(.rejectProtectionSpace, nil)
        }
    }
}
extension AuthChallengeDisposition? {
    /// Pass challenge to next responder
    static let next = AuthChallengeDisposition?.none
}

enum NavigationActionPolicy {
    case allow
    case cancel
    case download
    // TODO: maybe URL instead? what about POST?
    case redirect(request: URLRequest)

    case retarget(in: WindowFeatures)

    static func redirect(to url: URL) -> NavigationActionPolicy {
        return .redirect(request: URLRequest(url: url))
    }
}

struct NavigationPreferences {
    var userAgent: String?
    var contentMode: WKWebpagePreferences.ContentMode
    private var _javaScriptEnabled: Bool
    @available(macOS 11.0, *)
    var javaScriptEnabled: Bool {
        get {
            _javaScriptEnabled
        }
        set {
            _javaScriptEnabled = newValue
        }
    }

    init(userAgent: String?, preferences: WKWebpagePreferences) {
        self.contentMode = preferences.preferredContentMode
        if #available(macOS 11.0, *) {
            self._javaScriptEnabled = preferences.allowsContentJavaScript
        } else {
            self._javaScriptEnabled = true
        }
    }

    func export(to preferences: WKWebpagePreferences) {
        preferences.preferredContentMode = contentMode
        if #available(macOS 11.0, *) {
            preferences.allowsContentJavaScript = javaScriptEnabled
        }
    }
}

extension NavigationActionPolicy? {
    /// Pass decision making to next responder
    static let next = NavigationActionPolicy?.none
}

extension WKNavigationResponsePolicy? {
    /// Pass decision making to next responder
    static let next = WKNavigationResponsePolicy?.none
}

protocol NavigationResponder {

    // MARK: - Expectation

    // Item is nil if the gesture ended without navigation.
    @MainActor
    func webView(_ webView: WebView, didEndNavigationGestureWithNavigationTo backForwardListItem: WKBackForwardListItem?)

    /// Called when WebView navigation is initated by `goBack`, `goForward` and `goToBackForwardListItem:` methods
    /// won‘t get called when a Page Web Process is hung, should handle using methods above and navigation gestures callback
    /// !!! called twice: before _webViewDidEndNavigationGesture: and after decidePolicyForNavigationAction:
    @MainActor
    func webView(_ webView: WebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool)

    /// called when WebView navigation is initiated by `loadRequest:` method
    @MainActor
    func webView(_ webView: WebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest)

    /// Called when WebView navigation is initated by `reload` method
    @MainActor
    func webView(_ webView: WebView, willStartReloadNavigation navigation: WKNavigation?)

    /// Called when WebView navigation is initated by `goBack`, `goForward` and `goToBackForwardListItem:` methods
    @MainActor
    func webView(_ webView: WebView, willStartUserInitiatedNavigation navigation: WKNavigation?, to backForwardListItem: WKBackForwardListItem?)

    @MainActor
    func webView(_ webView: WebView, willRequestNewWebViewFor url: URL, inTargetNamed target: TargetWindowName?, windowFeatures: WindowFeatures?)

    /// called when WebView is about to restore Session State
    @MainActor
    func webViewWillRestoreSessionState(_ webView: WebView)

    // MARK: Decision making

    /// Decides whether to allow or cancel a navigation.
    @MainActor
    func webView(_ webView: WebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy?

    // MARK: Navigation

    /// Invoked when the web view needs to respond to an authentication challenge.
    @MainActor
    func webView(_ webView: WebView, didReceive challenge: URLAuthenticationChallenge) async -> AuthChallengeDisposition?

    @MainActor
    func webView(_ webView: WebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy?

    /// Invoked when a server redirect is received for the main
    @MainActor
    func webView(_ webView: WebView, didReceiveServerRedirectFor navigation: WKNavigation)

    @MainActor
    func webView(_ webView: WebView, didStart navigation: WKNavigation, with request: URLRequest)
    @MainActor
    func webView(_ webView: WebView, didStartNavigationWith request: URLRequest, in frame: WKFrameInfo)

    @MainActor
    func webView(_ webView: WebView, didCommit navigation: WKNavigation, with request: URLRequest)
    @MainActor
    func webView(_ webView: WebView, didCommitNavigationWith request: URLRequest, in frame: WKFrameInfo)

    @MainActor
    func webView(_ webView: WebView, backForwardListItemAdded itemAdded: WKBackForwardListItem, itemsRemoved: [WKBackForwardListItem])

    @MainActor
    func webView(_ webView: WebView, didFinish navigation: WKNavigation, with request: URLRequest)
    @MainActor
    func webView(_ webView: WebView, didFinishNavigationWith request: URLRequest, in frame: WKFrameInfo)

    @MainActor
    func webView(_ webView: WebView, navigation: WKNavigation, with request: URLRequest, didFailWith error: Error)
    @MainActor
    func webView(_ webView: WebView, navigationWith request: URLRequest, in frame: WKFrameInfo, didFailWith error: Error)

    @MainActor
    func webView(_ webView: WebView, willPerformClientRedirectTo url: URL, delay: TimeInterval)

    @MainActor
    func webView(_ webView: WebView, navigationAction: WKNavigationAction, didBecome download: WebKitDownload)
    @MainActor
    func webView(_ webView: WebView, navigationResponse: WKNavigationResponse, didBecome download: WebKitDownload)
    @MainActor
    func webView(_ webView: WebView, contextMenuDidCreate download: WebKitDownload)

    @MainActor
    func webView(_ webView: WebView, webContentProcessDidTerminateWith reason: WebProcessTerminationReason?)

    //
    //
    //    /** @abstract Invoked when the web view is establishing a network connection using a deprecated version of TLS.
    //     @param webView The web view initiating the connection.
    //     @param challenge The authentication challenge.
    //     @param decisionHandler The decision handler you must invoke to respond to indicate whether or not to continue with the connection establishment.
    //     */
    //    @available(macOS 11.0, *)
    //    func webView(_ webView: WebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void)
    //
    //    /** @abstract Invoked when the web view is establishing a network connection using a deprecated version of TLS.
    //     @param webView The web view initiating the connection.
    //     @param challenge The authentication challenge.
    //     @param decisionHandler The decision handler you must invoke to respond to indicate whether or not to continue with the connection establishment.
    //     */
    //    @available(macOS 11.0, *)
    //    func webView(_ webView: WebView, shouldAllowDeprecatedTLSFor challenge: URLAuthenticationChallenge) async -> Bool
    //
    //

}

extension NavigationResponder {

    func webView(_ webView: WebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool) {}
    func webView(_ webView: WebView, willStartUserInitiatedNavigation _: WKNavigation?, to _: WKBackForwardListItem?) {}
    func webView(_ webView: WebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest) {}
    func webView(_ webView: WebView, willStartReloadNavigation navigation: WKNavigation?) {}
    func webView(_ webView: WebView, didEndNavigationGestureWithNavigationTo _: WKBackForwardListItem?) {}
    func webView(_ webView: WebView, willRequestNewWebViewFor url: URL, inTargetNamed target: TargetWindowName?, windowFeatures: WindowFeatures?) {}
    func webViewWillRestoreSessionState(_ webView: WebView) {}

    func webView(_: WebView, decidePolicyFor _: WKNavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        return .next
    }

    func webView(_ webView: WebView, didReceive challenge: URLAuthenticationChallenge) async -> AuthChallengeDisposition? {
        return .next
    }

    func webView(_ webView: WebView, didReceiveServerRedirectFor navigation: WKNavigation) {}

    func webView(_ webView: WebView, decidePolicyFor _: WKNavigationResponse) async -> WKNavigationResponsePolicy? {
        return .next
    }

    func webView(_ webView: WebView, didStartNavigationWith request: URLRequest, in frame: WKFrameInfo) {}
    func webView(_ webView: WebView, didStart navigation: WKNavigation, with request: URLRequest) {}

    func webView(_ webView: WebView, didCommitNavigationWith request: URLRequest, in frame: WKFrameInfo) {}
    func webView(_ webView: WebView, didCommit navigation: WKNavigation, with request: URLRequest) {}

    func webView(_ webView: WebView, backForwardListItemAdded itemAdded: WKBackForwardListItem, itemsRemoved: [WKBackForwardListItem]) {}

    func webView(_ webView: WebView, didFinishNavigationWith request: URLRequest, in frame: WKFrameInfo) {}
    func webView(_ webView: WebView, didFinish navigation: WKNavigation, with request: URLRequest) {}

    func webView(_ webView: WebView, navigationWith request: URLRequest, in frame: WKFrameInfo, didFailWith: Error) {}
    func webView(_ webView: WebView, navigation: WKNavigation, with request: URLRequest, didFailWith error: Error) {}

    func webView(_ webView: WebView, willPerformClientRedirectTo url: URL, delay: TimeInterval) {}

    func webView(_ webView: WebView, navigationAction: WKNavigationAction, didBecome download: WebKitDownload) {}
    func webView(_ webView: WebView, navigationResponse: WKNavigationResponse, didBecome download: WebKitDownload) {}
    func webView(_ webView: WebView, contextMenuDidCreate download: WebKitDownload) {}

    func webView(_ webView: WebView, webContentProcessDidTerminateWith reason: WebProcessTerminationReason?) {}

}
