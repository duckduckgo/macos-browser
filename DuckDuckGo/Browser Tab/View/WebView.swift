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

protocol WebViewContextMenuDelegate: AnyObject {
    func webView(_ webView: WebView, willOpenContextMenu menu: NSMenu, with event: NSEvent)
    func webView(_ webView: WebView, didCloseContextMenu menu: NSMenu, with event: NSEvent?)
}

final class WebView: WKWebView {

    weak var contextMenuDelegate: WebViewContextMenuDelegate?

    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }

    // MARK: - Zoom

    static let maxZoomLevel: CGFloat = 3.0
    static let minZoomLevel: CGFloat = 0.5
    static private let zoomLevelStep: CGFloat = 0.1

    var zoomLevel: CGFloat {
        get {
            if #available(macOS 11.0, *) {
                return pageZoom
            }
            return magnification
        }
        set {
            let cappedValue = min(Self.maxZoomLevel, max(Self.minZoomLevel, newValue))
            if #available(macOS 11.0, *) {
                pageZoom = cappedValue
            } else {
                magnification = cappedValue
            }
        }
    }

    var canZoomToActualSize: Bool {
        self.window != nil && (self.zoomLevel != 1.0 || self.magnification != 1.0)
    }

    var canZoomIn: Bool {
        self.window != nil && self.zoomLevel < Self.maxZoomLevel
    }

    var canZoomOut: Bool {
        self.window != nil && self.zoomLevel > Self.minZoomLevel
    }

    func resetZoomLevel() {
        zoomLevel = 1.0
        magnification = 1.0
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
        contextMenuDelegate?.webView(self, willOpenContextMenu: menu, with: event)
    }

    override func didCloseMenu(_ menu: NSMenu, with event: NSEvent?) {
        super.didCloseMenu(menu, with: event)
        contextMenuDelegate?.webView(self, didCloseContextMenu: menu, with: event)
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
