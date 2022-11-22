//
//  WebViewNavigationDelegate.swift
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

enum CreateWebViewDecision {
    case allow
    case deny
}

@MainActor
@objc protocol WebViewNavigationDelegate: WKNavigationDelegate {

    // MARK: - Navigation Expectation
    /// called when WebView navigation is initiated by `loadRequest:` method
    @objc optional func webView(_ webView: WebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest)

    /// Called when WebView navigation is initated by `reload` method
    @objc optional func webView(_ webView: WebView, willStartReloadNavigation navigation: WKNavigation?)

    /// Called when WebView navigation is initated by `goBack`, `goForward` and `goToBackForwardListItem:` methods
    @objc optional func webView(_ webView: WebView, willStartUserInitiatedNavigation navigation: WKNavigation?, to backForwardListItem: WKBackForwardListItem?)

    /// called when window.open is evaluated in WebView to open URL in a new tab/window
    @objc optional func webView(_ webView: WebView, willRequestNewWebViewFor url: URL, inTargetNamed target: String?, windowFeatures: WindowFeatures?)

    /// called when WebView is about to restore Session State
    @objc optional func webViewWillRestoreSessionState(_ webView: WebView)

    // MARK: Private WebKit methods

    // Item is nil if the gesture ended without navigation.
    @objc(_webViewDidEndNavigationGesture:withNavigationToBackForwardListItem:)
    optional func webView(_ webView: WKWebView, didEndNavigationGestureWithNavigationTo backForwardListItem: WKBackForwardListItem?)

    // won‘t be called when a Page Web Process is hung, should handle using methods above and navigation gestures callback
    @objc(_webView:willGoToBackForwardListItem:inPageCache:)
    optional func webView(_ webView: WKWebView, willGoTo backForwardListItem: WKBackForwardListItem, inPageCache: Bool)

    @objc(_webView:didStartProvisionalLoadWithRequest:inFrame:)
    optional func webView(_ webView: WKWebView, didStartProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo)

    @objc(_webView:didCommitLoadWithRequest:inFrame:)
    optional func webView(_ webView: WKWebView, didCommitLoadWith request: URLRequest, in frame: WKFrameInfo)

    @objc(_webView:backForwardListItemAdded:removed:)
    optional func webView(_ webView: WKWebView, backForwardListItemAdded itemAdded: WKBackForwardListItem, itemsRemoved: [WKBackForwardListItem])

    @objc(_webView:willPerformClientRedirectToURL:delay:)
    optional func webView(_ webView: WKWebView, willPerformClientRedirectTo url: URL, delay: TimeInterval)

    @objc(_webView:didFinishLoadWithRequest:inFrame:)
    optional func webView(_ webView: WKWebView, didFinishLoadWith request: URLRequest, in frame: WKFrameInfo)

    @objc(_webView:didFailProvisionalLoadWithRequest:inFrame:withError:)
    optional func webView(_ webView: WKWebView, didFailProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error)
    @objc(_webView:didFailLoadWithRequest:inFrame:withError:)
    func webView(_ webView: WKWebView, didFailLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error)

    /// Called when WebView Context Menu Save/Download item is chosen
    @available(macOS 11.3, *)
    @objc(_webView:contextMenuDidCreateDownload:)
    optional func webView(_ webView: WKWebView, contextMenuDidCreate download: WKDownload)

    @objc(_webView:webContentProcessDidTerminateWithReason:)
    optional func webView(_ webView: WKWebView, webContentProcessDidTerminateWith reason: Int)

}

enum WebProcessTerminationReason: Int {
    case exceededMemoryLimit = 0
    case exceededCPULimit
    case requestedByClient
    case crash
}
