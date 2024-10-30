//
//  WebViewContainerView.swift
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

import AppKit
import Combine

final class WebViewContainerView: NSView {
    @objc
    let webView: WebView
    weak var tab: Tab?

    override var constraints: [NSLayoutConstraint] {
        // return nothing to WKFullScreenWindowController which will keep the constraints
        // and crash after trying to reactivate them as the ContainerView will be gone by the moment
        // and NSLayouConstraint has unsafe/unowned references to its views
        return []
    }

    init(tab: Tab, webView: WebView, frame: NSRect) {
        self.webView = webView
        self.tab = tab
        super.init(frame: frame)

        self.autoresizingMask = [.width, .height]
        webView.translatesAutoresizingMaskIntoConstraints = true

        // WebView itself or FullScreen Placeholder view
        let displayedView = webView.tabContentView
        displayedView.frame = self.bounds
        displayedView.autoresizingMask = [.width, .height]
        self.addSubview(displayedView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var blurViewIsHiddenCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    override func layout() {
        super.layout()
        webView.tabContentView.frame = bounds
    }

    override func didAddSubview(_ subview: NSView) {
        // if fullscreen placeholder is shown
        guard self.webView.tabContentView !== self.webView else {
            cancellables.removeAll()
            return
        }

        subview.frame = self.bounds
        // fix Inspector snapshot not being blurred completely on fullscreen enter
        if let blurView = subview.subviews.first(where: { $0 is NSVisualEffectView }),
           blurView.frame != subview.bounds {

            blurView.frame = subview.bounds
            // and fix the glitch
            blurView.isHidden = false
            // try softening the glitch on fullscreen exit
            blurViewIsHiddenCancellable = blurView.publisher(for: \.isHidden)
                .sink { [weak blurView] isHidden in
                    if isHidden {
                        blurView?.isHidden = false
                    }
                }
        }

        cancellables.removeAll()

        // associate the Tab with the WebView when it gets moved to Full Screen Window Controller
        // this will help to identify an active Tab when we receive the Main Menu events in Full Screen mode
        webView.publisher(for: \.window)
            .sink { [weak self, weak tab] fullScreenWindow in
                guard let self, let fullScreenWindow,
                      let fullScreenWindowController = fullScreenWindow.windowController,
                      // only hits once per ContainerView when the WebView is moved from MainWindow to Full Screen Window Controller
                      !(fullScreenWindowController is MainWindowController) else { return }

                fullScreenWindowController.associatedTab = tab

                self.observeTabMainWindow(fullScreenWindowController)
                self.observeFullScreenWindowWillExitFullScreen(fullScreenWindowController)
            }
            .store(in: &cancellables)
    }

    /// fix handling keyboard shortcuts in Full Screen mode
    private func observeTabMainWindow(_ fullScreenWindowController: NSWindowController) {
        guard webView !== webView.tabContentView else {
            assertionFailure("WebView Replacement view should be present")
            return
        }

        // observe WebView Replacement View moved to another Main Window (which means the Tab was dragged out)
        webView.tabContentView.publisher(for: \.window)
            .sink { window in
                guard let mainViewController = window?.windowController?.contentViewController else { return }
                assert(mainViewController is MainViewController)

                // when the Full Screen Window Controller receives Main Menu events
                // they should be redirected to the Tab owning MainViewController
                fullScreenWindowController.nextResponder = mainViewController
            }
            .store(in: &cancellables)
    }

    /** 

     Fix a glitch breaking the Full Screen presentation on a repeated
     Full Screen mode activation after dragging out of Mission Control Spaces.

     **Steps to reproduce:**
     1. Enter full screen video
     2. Open Mission Control (swipe three fingers up)
     3. Drag the full screen video out of the top panel in the Mission Control
     4. Enter full screen again - validate video opens in full screen
     - The video would open in a shrinked (thumbnail) state without the fix

     - Note: The bug is actual for macOS 12 and above

     https://app.asana.com/0/1177771139624306/1204370242122745/f
    */
    private func observeFullScreenWindowWillExitFullScreen(_ fullScreenWindowController: NSWindowController) {
        guard #available(macOS 12.0, *) else { return } // works fine on Big Sur
        NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification, object: fullScreenWindowController.window)
            .sink { [weak self, weak fullScreenWindowController] _ in
                guard let self else { return }
                self.cancellables.removeAll()

                if NSWorkspace.isMissionControlActive(),
                   let fullScreenWindowController, fullScreenWindowController.responds(to: Selector.initWithWindowWebViewPage) {
                    // we have no access to `WebViewImpl::closeFullScreenWindowController()` method that would just work closing the
                    // WKFullScreenWindowController and reset a full screen manager reference to it.
                    // - if we call `close` method directly on the Window Controller – the reference in WebViewImpl will remain dangling leading to a crash later.
                    // - we may call `webView.closeAllMediaPresentations {}` but in case there‘s a Picture-In-Picture video run in parallel
                    //   this will lead to a crash because of [one-shot] close callback will be fired twice – for both full screen and PiP videos.
                    //   https://app.asana.com/0/1201037661562251/1207643414069383/f
                    //
                    // to overcome those issues we close the original full screen window here
                    // and re-initialize the existing WKFullScreenWindowController with a new window and updating its _webView reference
                    // by calling [WKFullScreenWindowController initWithWindow:webView:page:] for an already initialized controller
                    // so it can be reused again for full screen video presentation.
                    // https://github.com/WebKit/WebKit/blob/398e5e25e9f250e1a4e3f4dde3ae54dd09dbe23e/Source/WebKit/UIProcess/mac/WKFullScreenWindowController.mm#L96
                    //
                    DispatchQueue.main.async { [weak fullScreenWindowController, weak webView=self.webView] in
                        guard let webView, let fullScreenWindowController,
                              let window = fullScreenWindowController.window,
                              let pageRef = fullScreenWindowController.value(forKey: Key.page) else { return }

                        window.close()
                        fullScreenWindowController.window = nil

                        let newWindow = type(of: window).init(contentRect: NSScreen.main?.frame ?? .zero, styleMask: window.styleMask, backing: .buffered, defer: false)

                        fullScreenWindowController.perform(Selector.initWithWindowWebViewPage, withArguments: [newWindow, webView, NSValue(pointer: nil)])
                        fullScreenWindowController.setValue(pageRef, forKey: Key.page)

                        // prevent fullScreenWindowController getting released after we‘ve reset its window
                        _=Unmanaged.passUnretained(fullScreenWindowController).retain()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private enum Selector {
        static let initWithWindowWebViewPage = NSSelectorFromString("initWithWindow:webView:page:")
    }
    private enum Key {
        static let page = "page"
    }

    override func removeFromSuperview() {
        self.webView.tabContentView.removeFromSuperview()
        super.removeFromSuperview()
    }

    // MARK: NSDraggingDestination

    override func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return superview?.draggingEntered(draggingInfo) ?? .none
    }

    override func draggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return superview?.draggingUpdated(draggingInfo) ?? .none
    }

    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        return superview?.performDragOperation(draggingInfo) ?? false
    }

}

extension WebView {
    /// a parent (container) view displaying the WebView in the MainWindow hierarchy
    var containerView: WebViewContainerView? {
        // WebView is re-added to another Window hierarchy when in Full Screen media presentation mode
        // it creates a placeholder view added to the MainWindow hierarchy instead of it – `fullScreenPlaceholderView`
        superview as? WebViewContainerView ?? tabContentView.superview as? WebViewContainerView
    }
}

private extension NSWindowController {

    private static let associatedTabKey = UnsafeRawPointer(bitPattern: "associatedTabKey".hashValue)!
    private final class WeakTabRef: NSObject {
        weak var tab: Tab?
        init(tab: Tab) {
            self.tab = tab
        }
    }
    /// Associates a Tab object with a Web Content Full Screen Window Controller.
    /// Set when WebViewContainerView detects entering Full Screen mode.
    /// Used to determine a currently active Tab performing Full Screen media presentation while a Last known Key MainWindow may have another tab selected
    /// (see MainMenuActions.swift)
    var associatedTab: Tab? {
        get {
            (objc_getAssociatedObject(self, Self.associatedTabKey) as? WeakTabRef)?.tab
        }
        set {
            objc_setAssociatedObject(self, Self.associatedTabKey, newValue.map(WeakTabRef.init(tab:)), .OBJC_ASSOCIATION_RETAIN)
        }
    }

}

extension NSWindowController {

    /// Currently active (key) Tab: either a Key MainWindow‘s `selectedTab` or `associatedTab` of a Full Screen mediia presentation Window Controller (see above)
    var activeTab: Tab? {
        (self as? MainWindowController)?.mainViewController.tabCollectionViewModel.selectedTab
            ?? self.associatedTab
    }

}
