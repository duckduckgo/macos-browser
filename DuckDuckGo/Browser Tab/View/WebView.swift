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

    static let itemSelectors: [String: Selector] = [
        // Links
        "WKMenuItemIdentifierOpenLink": #selector(LinkMenuItemSelectors.openLinkInNewTab(_:)),
        "WKMenuItemIdentifierOpenLinkInNewWindow": #selector(LinkMenuItemSelectors.openLinkInNewWindow(_:)),
        "WKMenuItemIdentifierDownloadLinkedFile": #selector(LinkMenuItemSelectors.downloadLinkedFileAs(_:)),
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
        "WKMenuItemIdentifierSearchWeb": UserText.searchWithDuckDuckGo
    ]
  
    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }
  
    // MARK: - Zoom

    static private let maxZoomLevel: CGFloat = 3.0
    static private let minZoomLevel: CGFloat = 0.5
    static private let zoomLevelStep: CGFloat = 0.1

    var canZoomToActualSize: Bool {
        self.window != nil && self.pageZoom != 1.0
    }

    var canZoomIn: Bool {
        self.window != nil && self.pageZoom < Self.maxZoomLevel
    }

    var canZoomOut: Bool {
        self.window != nil && self.pageZoom > Self.minZoomLevel
    }

    func zoomIn() {
        guard canZoomIn else { return }
        self.pageZoom = min(self.pageZoom + Self.zoomLevelStep, Self.maxZoomLevel)
    }

    func zoomOut() {
        guard canZoomOut else { return }
        self.pageZoom = max(self.pageZoom - Self.zoomLevelStep, Self.minZoomLevel)
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

        menu.insertSeparatorBeforeItemWithIdentifier("WKMenuItemIdentifierCopyImage")

        menu.insertItemBeforeItemWithIdentifier("WKMenuItemIdentifierCopyImage",
                                                title: UserText.copyImageAddress,
                                                target: uiDelegate,
                                                selector: #selector(ImageMenuItemSelectors.copyImageAddress(_:)))

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
