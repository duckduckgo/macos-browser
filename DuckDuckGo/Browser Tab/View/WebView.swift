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

@objc(WebView)
final class WebView: WKWebView {

    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }

    // MARK: - Navigation

    @discardableResult
    override func load(_ request: URLRequest) -> WKNavigation? {
        let navigation = super.load(request)
//        extendedNavigationDelegate?.webView?(self, willStartNavigation: navigation, with: request)
        return navigation
    }

    func load(_ url: URL, in targetKind: NewWindowKind) {
//        extendedNavigationDelegate?.webView(self, willRequestNewWebViewFor: url, with: targetKind)
        // TODO: noopener, noreferrer?
        super.load(url, inTargetNamed: "_blank", windowFeatures: "noopener, noreferrer")
    }

    @available(*, unavailable)
    override func load(_ url: URL, inTargetNamed target: String?, windowFeatures: String?) {
        super.load(url, inTargetNamed: target, windowFeatures: windowFeatures)
    }

    @discardableResult
    override func reload() -> WKNavigation? {
        let navigation = super.reload()
//        extendedNavigationDelegate?.webView?(self, willStartReloadNavigation: navigation)
        return navigation
    }

    // TODO: LoadSimulated/File etc..
    // TODO: replaceLocation override
    // TODO: loadURLInFrame override

    // MARK: - Back/Forward Navigation

    @discardableResult
    override func go(to item: WKBackForwardListItem) -> WKNavigation? {
        let navigation = super.go(to: item)
//        extendedNavigationDelegate?.webView?(self, willStartUserInitiatedNavigation: navigation, to: item)
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

    // TODO: stop() navigation calls delegate failure method?

    // MARK: - Session State Restoration

    @available(macOS, deprecated: 12.0)
    override func restoreSessionState(from data: Data) throws {
        guard self.responds(to: #selector(WKWebView._restore(fromSessionStateData:))) else {
            throw DoesNotSupportRestoreFromSessionData()
        }
//        extendedNavigationDelegate?.webViewWillRestoreSessionState?(self)
        self._restore(fromSessionStateData: data)
    }

    @available(macOS 12, *)
    override var interactionState: Any? {
        get { super.interactionState }
        set {
//            extendedNavigationDelegate?.webViewWillRestoreSessionState?(self)
            super.interactionState = newValue
        }
    }

    // MARK: - Menu

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        // TODO: extendedUIDelegate?.webView?(self, willOpenContextMenu: menu, with: event)
    }

    override func didCloseMenu(_ menu: NSMenu, with event: NSEvent?) {
        super.didCloseMenu(menu, with: event)
        // TODO: extendedUIDelegate?.webView?(self, didCloseContextMenu: menu, with: event)
    }

}

enum NewWindowKind {
    case tab(selected: Bool)
    case popup(size: CGSize)
    case window(active: Bool)

    init(_ windowFeatures: WKWindowFeatures) {
        if windowFeatures.toolbarsVisibility?.boolValue ?? false {
            let windowContentSize = NSSize(width: windowFeatures.width?.intValue ?? 1024,
                                           height: windowFeatures.height?.intValue ?? 752)
            self = .popup(size: windowContentSize)
        } else {
            self = .tab(selected: false)
        }
    }
}
