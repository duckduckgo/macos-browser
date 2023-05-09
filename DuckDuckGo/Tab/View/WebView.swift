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

    var defaultZoomValue: DefaultZoomValue = .percent100

    var zoomLevel: DefaultZoomValue {
        get {
            if #available(macOS 11.0, *) {
                return DefaultZoomValue(rawValue: pageZoom) ?? .percent100
            }
            return DefaultZoomValue(rawValue: magnification) ?? .percent100
        }
        set {
            if #available(macOS 11.0, *) {
                pageZoom = newValue.rawValue
            } else {
                magnification = newValue.rawValue
            }
        }
    }

    var canZoomToActualSize: Bool {
        window != nil && zoomLevel != defaultZoomValue
    }

    var canZoomIn: Bool {
        window != nil && zoomLevel.index < DefaultZoomValue.allCases.count - 1
    }

    var canZoomOut: Bool {
        window != nil && zoomLevel.index > 0
    }

    func resetZoomLevel() {
        zoomLevel = defaultZoomValue
    }

    func zoomIn() {
        guard canZoomIn else { return }
        zoomLevel = DefaultZoomValue.allCases[self.zoomLevel.index + 1]
    }

    func zoomOut() {
        guard canZoomOut else { return }
        zoomLevel = DefaultZoomValue.allCases[self.zoomLevel.index - 1]
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

    // MARK: - NSDraggingDestination

    override func draggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        if NSApp.isCommandPressed || NSApp.isOptionPressed {
            return superview?.draggingUpdated(draggingInfo) ?? .none
        }

        let dragOperation = super.draggingUpdated(draggingInfo)
        guard dragOperation == .none,
              let superview else {
            return dragOperation
        }

        return superview.draggingUpdated(draggingInfo)
    }

    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        if NSApp.isCommandPressed || NSApp.isOptionPressed || super.draggingUpdated(draggingInfo) == .none {
            return superview?.performDragOperation(draggingInfo) ?? false
        }

        return super.performDragOperation(draggingInfo)
    }

}
