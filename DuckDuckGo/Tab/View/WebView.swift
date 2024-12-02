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

protocol WebViewInteractionEventsDelegate: AnyObject {
    func webView(_ webView: WebView, mouseDown event: NSEvent)
    func webView(_ webView: WebView, keyDown event: NSEvent)
    func webView(_ webView: WebView, scrollWheel event: NSEvent)
}

protocol WebViewZoomLevelDelegate: AnyObject {
    func zoomWasSet(to level: DefaultZoomValue)
}

@objc protocol WKInspectorDelegate {
    @MainActor @objc(inspector:openURLExternally:) optional func inspector(_ inspector: NSObject, openURLExternally url: NSURL?)
}

@objc(DuckDuckGo_WebView)
final class WebView: WKWebView {

    weak var contextMenuDelegate: WebViewContextMenuDelegate?
    weak var interactionEventsDelegate: WebViewInteractionEventsDelegate?
    weak var zoomLevelDelegate: WebViewZoomLevelDelegate?

    private var isLoadingObserver: Any?

    private var shouldShowWebInspector: Bool {
        // When a new tab is open, we don't want the web inspector to be active on screen and gain focus.
        // When a new tab is open the other tab views are removed from the window, hence, we should not show the web inspector.
        isInspectorShown && window != nil
    }

    override func addTrackingArea(_ trackingArea: NSTrackingArea) {
        /// disable mouseEntered/mouseMoved/mouseExited events passing to Web View while it‘s loading
        /// see https://app.asana.com/0/1177771139624306/1206990108527681/f
        if trackingArea.owner?.className == "WKMouseTrackingObserver" {
            // suppress Tracking Area events while loading
            isLoadingObserver = self.observe(\.isLoading, options: [.new]) { [weak self, trackingArea] _, c in
                if c.newValue /* isLoading */ ?? false {
                    guard let self, self.trackingAreas.contains(trackingArea) else { return }
                    removeTrackingArea(trackingArea)
                } else {
                    guard let self, !self.trackingAreas.contains(trackingArea) else { return }
                    superAddTrackingArea(trackingArea)
                }
            }
        }
        super.addTrackingArea(trackingArea)
    }

    private func superAddTrackingArea(_ trackingArea: NSTrackingArea) {
        super.addTrackingArea(trackingArea)
    }

    override var isInFullScreenMode: Bool {
        if #available(macOS 13.0, *) {
            return self.fullscreenState != .notInFullscreen
        } else {
            return self.tabContentView !== self
        }
    }

    func stopAllMedia(shouldStopLoading: Bool) {
        if shouldStopLoading {
            stopLoading()
        }
        stopMediaCapture()
        stopAllMediaPlayback()
        if isInFullScreenMode {
            fullscreenWindowController?.window?.toggleFullScreen(self)
        }
        if isInspectorShown {
            closeDeveloperTools()
        }
    }

    deinit {
        self.configuration.userContentController.removeAllUserScripts()
    }

    // MARK: - Zoom

    var defaultZoomValue: DefaultZoomValue = .percent100

    var zoomLevel: DefaultZoomValue {
        get {
            return DefaultZoomValue(rawValue: pageZoom) ?? .percent100
        }
        set {
            pageZoom = newValue.rawValue
        }
    }

    var canZoomToActualSize: Bool {
        window != nil && zoomLevel != defaultZoomValue && !self.isInFullScreenMode
    }

    var canResetMagnification: Bool {
        window != nil && magnification != 1
    }

    var canZoomIn: Bool {
        window != nil && zoomLevel.index < DefaultZoomValue.allCases.count - 1 && !self.isInFullScreenMode
    }

    var canZoomOut: Bool {
        window != nil && zoomLevel.index > 0 && !self.isInFullScreenMode
    }

    func resetZoomLevel() {
        magnification = 1
        zoomLevel = defaultZoomValue
        zoomLevelDelegate?.zoomWasSet(to: zoomLevel)
    }

    func zoomIn() {
        // if displaying PDF
        if let pdfHudView = self.hudView() {
            pdfHudView.zoomIn()
            return
        }
        guard canZoomIn else { return }
        zoomLevel = DefaultZoomValue.allCases[self.zoomLevel.index + 1]
        zoomLevelDelegate?.zoomWasSet(to: zoomLevel)
    }

    func zoomOut() {
        // if displaying PDF
        if let pdfHudView = self.hudView() {
            pdfHudView.zoomOut()
            return
        }
        guard canZoomOut else { return }
        zoomLevel = DefaultZoomValue.allCases[self.zoomLevel.index - 1]
        zoomLevelDelegate?.zoomWasSet(to: zoomLevel)
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

    // MARK: - Events

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        interactionEventsDelegate?.webView(self, mouseDown: event)
    }

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        interactionEventsDelegate?.webView(self, keyDown: event)
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        interactionEventsDelegate?.webView(self, scrollWheel: event)
    }

    // MARK: - Developer Tools

    var inspectorDelegate: WKInspectorDelegate? {
        get {
            inspectorPerform("delegate")?.takeUnretainedValue() as? WKInspectorDelegate
        }
        set {
            inspectorPerform("setDelegate:", with: newValue)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if shouldShowWebInspector {
            openDeveloperTools()
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
        if draggingInfo.draggingSource is WebView {
            return super.draggingUpdated(draggingInfo)
        }
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
        if draggingInfo.draggingSource is WebView {
            return super.performDragOperation(draggingInfo)
        }
        if NSApp.isCommandPressed || NSApp.isOptionPressed || super.draggingUpdated(draggingInfo) == .none {
            return superview?.performDragOperation(draggingInfo) ?? false
        }

        return super.performDragOperation(draggingInfo)
    }

    // MARK: - Find In Page

    enum FindResult: Error {
        case found(matches: UInt?)
        case notFound
        case cancelled
    }
    private var findInPageCompletionHandler: ((FindResult) -> Void)?

    @MainActor
    func find(_ string: String, with options: _WKFindOptions, maxCount: UInt) async -> FindResult {
        assert(!string.isEmpty)

        // native WKWebView find
        guard self.responds(to: Selector.findString) else {
            // fallback to official `findSting:`
            let config = WKFindConfiguration()
            config.backwards = options.contains(.backwards)
            config.caseSensitive = !options.contains(.caseInsensitive)
            config.wraps = options.contains(.wrapAround)

            return await withCheckedContinuation { continuation in
                self.find(string, configuration: config) { result in
                    continuation.resume(returning: result.matchFound ? .found(matches: nil) : .notFound)
                }
            }
        }

        _=Self.swizzleFindStringOnce

        // receive _WKFindDelegate calls and call completion handler
        NSException.try {
            self.setValue(self, forKey: "findDelegate")
        }
        if let findInPageCompletionHandler {
            self.findInPageCompletionHandler = nil
            findInPageCompletionHandler(.cancelled)
        }

        return await withCheckedContinuation { continuation in
            self.findInPageCompletionHandler = continuation.resume
            self.find(string, with: options, maxCount: maxCount)
        }
    }

    static private let swizzleFindStringOnce: () = {
        guard let originalMethod = class_getInstanceMethod(WebView.self, Selector.findString),
              let swizzledMethod = class_getInstanceMethod(WebView.self, #selector(find(_:with:maxCount:)))
        else {
            assertionFailure("Methods not available")
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    // swizzled method to call `_findString:withOptions:maxCount:` without performSelector: usage (as there‘s 3 args)
    @objc dynamic private func find(_ string: String, with options: _WKFindOptions, maxCount: UInt) {}

    func clearFindInPageState() {
        guard self.responds(to: Selector.hideFindUI) else {
            assertionFailure("_hideFindUI not available")
            return
        }
        self.perform(Selector.hideFindUI)
    }

    private enum Selector {
        static let findString = NSSelectorFromString("_findString:options:maxCount:")
        static let hideFindUI = NSSelectorFromString("_hideFindUI")
    }

}

extension WebView /* _WKFindDelegate */ {

    @objc(_webView:didFindMatches:forString:withMatchIndex:)
    func webView(_ webView: WKWebView, didFind matchesFound: UInt, for string: String, withMatchIndex _: Int) {
        if let findInPageCompletionHandler {
            self.findInPageCompletionHandler = nil
            findInPageCompletionHandler(.found(matches: matchesFound)) // matchIndex is broken in WebKit
        }
    }

    @objc(_webView:didFailToFindString:)
    func webView(_ webView: WKWebView, didFailToFind string: String) {
        if let findInPageCompletionHandler {
            self.findInPageCompletionHandler = nil
            findInPageCompletionHandler(.notFound)
        }
    }

}
