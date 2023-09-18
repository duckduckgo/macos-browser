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
    private var fullScreenWindowWillCloseCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

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
                self.observeFullScreenWindowWillExitFullScreen(fullScreenWindow)
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

    // fix a glitch scaling down Full Screen layer on next Full Screen activation
    // after exiting Full Screen by dragging the window out in Mission Control
    // (three-fingers-up swipe)
    // see https://app.asana.com/0/1177771139624306/1204370242122745/f
    private func observeFullScreenWindowWillExitFullScreen(_ fullScreenWindow: NSWindow) {
        NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification, object: fullScreenWindow)
            .sink { [weak self] _ in
                guard let self else { return }
                self.cancellables.removeAll()

                if NSWorkspace.isMissionControlActive() {
                    // closeAllMediaPresentations causes all Full Screen windows to be closed and removed from their WebViews
                    // (and reinstantiated the next time Full Screen is requested)
                    // this would slightly break UX in case multiple Full Screen windows are open but it fixes the bug
                    if #available(macOS 12.0, *) {
                        webView.closeAllMediaPresentations {}
                    } else if #available(macOS 11.4, *) {
                        webView.closeAllMediaPresentations()
                    }

                }
            }
            .store(in: &cancellables)

        fullScreenWindowWillCloseCancellable = NotificationCenter.default.publisher(for: NSWindow.willCloseNotification, object: fullScreenWindow)
            .sink { [weak self] notification in
                self?.fullScreenWindowWillCloseCancellable = nil
                let fullScreenWindowController = (notification.object as? NSWindow)?.windowController
                DispatchQueue.main.async { [weak fullScreenWindowController] in
                    guard let fullScreenWindowController else { return }
                    // just in case.
                    // if WKFullScreenWindowController receives `close()` the next time it‘s open it will crash because its _webView is nil
                    // https://errors.duckduckgo.com/organizations/ddg/issues/3411/?project=6&referrer=release-issue-stream
                    NSException.try {
                        fullScreenWindowController.setValue(NSView(), forKeyPath: #keyPath(webView))
                    }

                }
            }

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
