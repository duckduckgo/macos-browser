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

@objc protocol WebViewNavigationDelegate: WKNavigationDelegate {

    /// called when WebView navigation is initiated by `loadRequest:` method
    @objc optional func webView(_ webView: WKWebView, willStartNavigation navigation: WKNavigation?, with request: URLRequest)

    /// Called when WebView navigation is initated by `reload` method
    @objc optional func webView(_ webView: WKWebView, willStartReloadNavigation navigation: WKNavigation?)

    /// Called when WebView navigation is initated by `goBack`, `goForward` and `goToBackForwardListItem:` methods
    @objc optional func webView(_ webView: WKWebView, willStartUserInitiatedNavigation navigation: WKNavigation?, to backForwardListItem: WKBackForwardListItem?)

    /// called when WebView is about to restore Session State
    @objc optional func webViewWillRestoreSessionState(_ webView: WKWebView)

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

    @objc(_webView:willPerformClientRedirectToURL:delay:)
    optional func webView(_ webView: WKWebView, willPerformClientRedirectTo url: URL, delay: TimeInterval)

    @objc(_webView:didFinishLoadWithRequest:inFrame:)
    optional func webView(_ webView: WKWebView, didFinishLoadWith request: URLRequest, in frame: WKFrameInfo)

    @objc(_webView:didFailProvisionalLoadWithRequest:inFrame:withError:)
    optional func webView(_ webView: WKWebView, didFailProvisionalLoadWith request: URLRequest, in frame: WKFrameInfo, with error: Error)

    /// Called when WebView Context Menu Save/Download item is chosen
    @objc(_webView:contextMenuDidCreateDownload:)
    optional func webView(_ webView: WKWebView, contextMenuDidCreate download: WebKitDownload)

}

extension WebView {

    override var navigationDelegate: WKNavigationDelegate? {
        get { super.navigationDelegate }
        set {
            assert(newValue is WebViewNavigationDelegate?)
            super.navigationDelegate = newValue
        }
    }

    private var navDelegate: WebViewNavigationDelegate? {
        (self.navigationDelegate as? WebViewNavigationDelegate?)!
    }

    // ...

    override func load(_ request: URLRequest) -> WKNavigation? {
        let navigation = super.load(request)
        navDelegate?.webView?(self, willStartNavigation: navigation, with: request)
        return navigation
    }

    override func reload() -> WKNavigation? {
        let navigation = super.reload()
        navDelegate?.webView?(self, willStartReloadNavigation: navigation)
        return navigation
    }

    override func go(to item: WKBackForwardListItem) -> WKNavigation? {
        let navigation = super.go(to: item)
        navDelegate?.webView?(self, willStartUserInitiatedNavigation: navigation, to: item)
        return navigation
    }
//    override func goBack() -> WKNavigation? { /* same */ }
//    override func goForward() -> WKNavigation? { /* same */ }

    // ...

    @available(macOS, deprecated: 12.0)
    func restoreSessionState(from data: Data) throws {
        guard self.responds(to: #selector(WKWebView._restore(fromSessionStateData:))) else {
            throw DoesNotSupportRestoreFromSessionData()
        }
        navDelegate?.webViewWillRestoreSessionState?(self)
        self._restore(fromSessionStateData: data)
    }

    @available(macOS 12, *)
    override var interactionState: Any? {
        get { super.interactionState }
        set {
            navDelegate?.webViewWillRestoreSessionState?(self)
            super.interactionState = newValue
        }
    }

}

extension URLRequest {

    private static let requestAttributionKey = "requestAttribution"
    /// Used instead of macOS-12 introduced request.attribution property to differentiate user-initiated vs. developer-initiated requests
    var requestAttribution: URLRequestAttribution {
        get {
            if #available(macOS 12.0, *) {
                return URLRequestAttribution(rawValue: self.attribution.rawValue)
            } else {
                return URLRequestAttribution(rawValue: (objc_getAssociatedObject(self, Self.requestAttributionKey) as? NSNumber)?.uintValue ?? 0)
            }
        }
        set {
            if #available(macOS 12.0, *) {
                self.attribution = Attribution(rawValue: newValue.rawValue) ?? .developer
            } else {
                objc_setAssociatedObject(self, Self.requestAttributionKey, NSNumber(value: newValue.rawValue), .OBJC_ASSOCIATION_RETAIN)
            }
        }
    }
    var isUserInitiated: Bool { requestAttribution == .user }
    
}

struct URLRequestAttribution: RawRepresentable {
    var rawValue: UInt

    /// Automatically or developer-initiated request
    static let developer: URLRequestAttribution = {
        URLRequestAttribution(rawValue: {
            if #available(macOS 12.0, *) {
                return URLRequest.Attribution.developer.rawValue
            } else {
                return 0
            }
        }())
    }()
    /// Request initiated by a user intent (userEntered)
    static let user: URLRequestAttribution = {
        URLRequestAttribution(rawValue: {
            if #available(macOS 12.0, *) {
                return URLRequest.Attribution.developer.rawValue
            } else {
                return 1
            }
        }())
    }()

}

final class WebView: WKWebView {

    static let itemSelectors: [String: Selector] = [
        // Links
        "WKMenuItemIdentifierOpenLink": #selector(LinkMenuItemSelectors.openLinkInNewTab(_:)),
        "WKMenuItemIdentifierOpenLinkInNewWindow": #selector(LinkMenuItemSelectors.openLinkInNewWindow(_:)),
        "WKMenuItemIdentifierDownloadLinkedFile": #selector(LinkMenuItemSelectors.downloadLinkedFileAs(_:)),
        "WKMenuItemIdentifierDownloadMedia": #selector(LinkMenuItemSelectors.downloadLinkedFileAs(_:)),
        "WKMenuItemIdentifierAddLinkToBookmarks": #selector(LinkMenuItemSelectors.addLinkToBookmarks(_:)),
        "WKMenuItemIdentifierCopyLink": #selector(LinkMenuItemSelectors.copyLink(_:)),

        // Images
        "WKMenuItemIdentifierOpenImageInNewWindow": #selector(ImageMenuItemSelectors.openImageInNewWindow(_:)),
        "WKMenuItemIdentifierDownloadImage": #selector(ImageMenuItemSelectors.saveImageAs(_:)),

        "WKMenuItemIdentifierSearchWeb": #selector(MenuItemSelectors.search(_:))
    ]

    static let itemTitles: [String: String] = [
        "WKMenuItemIdentifierOpenLink": UserText.openLinkInNewTab,
        "WKMenuItemIdentifierDownloadImage": UserText.saveImageAs,
        "WKMenuItemIdentifierDownloadLinkedFile": UserText.downloadLinkedFileAs,
        "WKMenuItemIdentifierAddLinkToBookmarks": UserText.addLinkToBookmarks,
        "WKMenuItemIdentifierBookmarkPage": UserText.bookmarkPage,
        "WKMenuItemIdentifierSearchWeb": UserText.searchWithDuckDuckGo
    ]

    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }

    // MARK: - Zoom

    static private let maxZoomLevel: CGFloat = 3.0
    static private let minZoomLevel: CGFloat = 0.5
    static private let zoomLevelStep: CGFloat = 0.1

    var zoomLevel: CGFloat {
        get {
            if #available(macOS 11.0, *) {
                return pageZoom
            }
            return magnification
        }
        set {
            if #available(macOS 11.0, *) {
                pageZoom = newValue
            } else {
                magnification = newValue
            }
        }
    }

    var canZoomToActualSize: Bool {
        self.window != nil && self.zoomLevel != 1.0
    }

    var canZoomIn: Bool {
        self.window != nil && self.zoomLevel < Self.maxZoomLevel
    }

    var canZoomOut: Bool {
        self.window != nil && self.zoomLevel > Self.minZoomLevel
    }

    func zoomIn() {
        guard canZoomIn else { return }
        self.zoomLevel = min(self.zoomLevel + Self.zoomLevelStep, Self.maxZoomLevel)
    }

    func zoomOut() {
        guard canZoomOut else { return }
        self.zoomLevel = max(self.zoomLevel - Self.zoomLevelStep, Self.minZoomLevel)
    }

    // MARK: - Back/Forward Navigation

    var frozenCanGoBack: Bool?
    var frozenCanGoForward: Bool?

    override var canGoBack: Bool {
        frozenCanGoBack ?? super.canGoBack
    }

    override var canGoForward: Bool {
        frozenCanGoForward ?? super.canGoForward
    }

    // MARK: - Menu

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)

        updateActionsAndTitles(menu.items)

        menu.insertItemBeforeItemWithIdentifier("WKMenuItemIdentifierOpenImageInNewWindow",
                                                title: UserText.openImageInNewTab,
                                                target: uiDelegate,
                                                selector: #selector(ImageMenuItemSelectors.openImageInNewTab(_:)))

        menu.insertItemBeforeItemWithIdentifier("WKMenuItemIdentifierCopyLink",
                                                title: "Add Link to Bookmarks",
                                                target: uiDelegate,
                                                selector: #selector(LinkMenuItemSelectors.addLinkToBookmarks(_:)))

        menu.insertSeparatorBeforeItemWithIdentifier("WKMenuItemIdentifierCopyImage")

        menu.insertItemBeforeItemWithIdentifier("WKMenuItemIdentifierCopyImage",
                                                title: UserText.copyImageAddress,
                                                target: uiDelegate,
                                                selector: #selector(ImageMenuItemSelectors.copyImageAddress(_:)))

        menu.insertItemAfterItemWithIdentifier("WKMenuItemIdentifierReload",
                                               title: UserText.bookmarkPage,
                                               target: uiDelegate,
                                               selector: #selector(LinkMenuItemSelectors.bookmarkPage(_:)))

        // calling .menuWillOpen here manually as it's already calling the latter Menu Owner's willOpenMenu at this point
        (uiDelegate as? NSMenuDelegate)?.menuWillOpen?(menu)
    }

    private func updateActionsAndTitles(_ items: [NSMenuItem]) {
        items.forEach {
            guard let id = $0.identifier?.rawValue else { return }

            if let selector = Self.itemSelectors[id] {
                $0.target = uiDelegate
                $0.action = selector
            }

            if let title = Self.itemTitles[id] {
                $0.title = title
            }
        }
    }

    // MARK: - Developer Tools

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if self.isInspectorShown {
            self.openDeveloperTools()
        }
    }

    @nonobjc var mainFrame: AnyObject? {
        guard self.responds(to: NSSelectorFromString("_mainFrame")) else {
            assertionFailure("WKWebView does not respond to _mainFrame")
            return nil
        }
        return self.perform(NSSelectorFromString("_mainFrame"))?.takeUnretainedValue()
    }

    @discardableResult
    private func inspectorPerform(_ selectorName: String, with object: Any? = nil) -> Unmanaged<AnyObject>? {
        guard self.responds(to: NSSelectorFromString("_inspector")),
              let inspector = self.value(forKey: "_inspector") as? NSObject,
              inspector.responds(to: NSSelectorFromString(selectorName)) else {
            assertionFailure("_WKInspector does not respond to \(selectorName)")
            return nil
        }
        return inspector.perform(NSSelectorFromString(selectorName), with: object)
    }

    var isInspectorShown: Bool {
        return inspectorPerform("isVisible") != nil
    }

    @nonobjc func openDeveloperTools() {
        inspectorPerform("show")
    }

    @nonobjc func closeDeveloperTools() {
        inspectorPerform("close")
    }

    @nonobjc func openJavaScriptConsole() {
        inspectorPerform("showConsole")
    }

    @nonobjc func showPageSource() {
        guard let mainFrameHandle = self.mainFrame else { return }
        inspectorPerform("showMainResourceForFrame:", with: mainFrameHandle)
    }

    @nonobjc func showPageResources() {
        inspectorPerform("showResources")
    }

    // MARK: - Fullscreen

    /// actual view to be displayed as a Tab content
    /// may be the WebView itself or FullScreen Placeholder view
    var tabContentView: NSView {
        return fullScreenPlaceholderView ?? self
    }

    var fullscreenWindowController: NSWindowController? {
        guard let fullscreenWindowController = self.window?.windowController,
              fullscreenWindowController.className.contains("FullScreen")
        else {
            return nil
        }
        return fullscreenWindowController
    }

}
