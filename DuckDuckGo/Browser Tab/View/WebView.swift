//
//  WebView.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import WebKit
import os.log

final class WebView: WKWebView {

    var extendedNavigationDelegate: WebViewNavigationDelegate? {
        get { navigationDelegate as? WebViewNavigationDelegate }
        set { navigationDelegate = newValue }
    }

    var extendedUIDelegate: WebViewUIDelegate? {
        get { uiDelegate as? WebViewUIDelegate }
        set { uiDelegate = newValue }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Reopen Developer Tools when moved to another window
        if self.isInspectorShown {
            self.openDeveloperTools()
        }
    }

    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }

    // MARK: - Navigation

    @discardableResult
    override func load(_ request: URLRequest) -> WKNavigation? {
        let navigation = super.load(request)
        extendedNavigationDelegate?.webView?(self, willStartNavigation: navigation, with: request)
        return navigation
    }

    override func load(_ url: URL, inTargetNamed target: String?, windowFeatures: WindowFeatures? = nil) {
        extendedNavigationDelegate?.webView?(self, willRequestNewWebViewFor: url, inTargetNamed: target, windowFeatures: windowFeatures)
        super.load(url, inTargetNamed: target, windowFeatures: windowFeatures)
    }

    @discardableResult
    override func reload() -> WKNavigation? {
        let navigation = super.reload()
        extendedNavigationDelegate?.webView?(self, willStartReloadNavigation: navigation)
        return navigation
    }

    // TODO: LoadSimulated/File etc..

    // MARK: - Back/Forward Navigation

    @discardableResult
    override func go(to item: WKBackForwardListItem) -> WKNavigation? {
        let navigation = super.go(to: item)
        extendedNavigationDelegate?.webView?(self, willStartUserInitiatedNavigation: navigation, to: item)
        return navigation
    }

    @discardableResult
    override func goBack() -> WKNavigation? {
        backForwardList.backItem.flatMap { self.go(to: $0) }
    }

    @discardableResult
    override func goForward() -> WKNavigation? {
        backForwardList.forwardItem.flatMap { self.go(to: $0) }
    }

    // TODO: Stop navigation calls delegate failure method?

    // TODO: Move to Tab Extension
    var frozenCanGoBack: Bool?
    var frozenCanGoForward: Bool?

    override var canGoBack: Bool {
        frozenCanGoBack ?? super.canGoBack
    }

    override var canGoForward: Bool {
        frozenCanGoForward ?? super.canGoForward
    }

    // MARK: - Session State Restoration

    @available(macOS, deprecated: 12.0)
    override func restoreSessionState(from data: Data) throws {
        guard self.responds(to: #selector(WKWebView._restore(fromSessionStateData:))) else {
            throw DoesNotSupportRestoreFromSessionData()
        }
        extendedNavigationDelegate?.webViewWillRestoreSessionState?(self)
        self._restore(fromSessionStateData: data)
    }

    @available(macOS 12, *)
    override var interactionState: Any? {
        get { super.interactionState }
        set {
            extendedNavigationDelegate?.webViewWillRestoreSessionState?(self)
            super.interactionState = newValue
        }
    }

    // MARK: - Menu

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        extendedUIDelegate?.webView?(self, willOpenContextMenu: menu, with: event)
    }

    override func didCloseMenu(_ menu: NSMenu, with event: NSEvent?) {
        super.didCloseMenu(menu, with: event)
        extendedUIDelegate?.webView?(self, didCloseContextMenu: menu, with: event)
    }

}
