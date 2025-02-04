//
//  ZoomPopover.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import AppKitExtensions
import Combine

final class ZoomPopover: NSPopover, ZoomPopoverViewControllerDelegate {

    fileprivate enum Constants {
        static let defaultToolbarHideUiInterval: TimeInterval = 2
        static let defaultMenuHideUiInterval: TimeInterval = 4
    }

    private var tabViewModel: TabViewModel
    private weak var addressBar: NSView?
    private var positioningViewIsMouseOverCancellable: NSKeyValueObservation?
    private var autoCloseCancellables = Set<AnyCancellable>()

    @UserDefaultsWrapper(key: .zoomToolbarHideUiInterval, defaultValue: Constants.defaultToolbarHideUiInterval)
    private var zoomToolbarHideUiInterval: TimeInterval

    @UserDefaultsWrapper(key: .zoomMenuHideUiInterval, defaultValue: Constants.defaultMenuHideUiInterval)
    private var zoomMenuHideUiInterval: TimeInterval

    enum Source { case toolbar, menu }
    private var source: Source?

    private var hideUiInterval: TimeInterval? {
        let interval = switch source {
        case .toolbar:
            zoomToolbarHideUiInterval
        case .menu:
            zoomMenuHideUiInterval
        case .none:
            -1.0
        }
        guard interval > 0 else { return nil } // no auto-hide
        return interval
    }

    /// offset from the address bar x to avoid popover arrow clipping if positioning view is too close to the edge
    private var offsetX: CGFloat = 0

    /// prefferred bounding box for the popover positioning
    override var boundingFrame: NSRect {
        guard let addressBar,
              let window = addressBar.window else { return .infinite }
        var frame = window.convertToScreen(addressBar.convert(addressBar.bounds, to: nil))
        frame = frame.insetBy(dx: 0, dy: -window.frame.size.height)
        frame.origin.x += offsetX
        return frame
    }

    /// position popover to the right
    override func adjustFrame(_ frame: NSRect) -> NSRect {
        let boundingFrame = self.boundingFrame
        guard !boundingFrame.isInfinite else { return frame }
        var frame = frame
        frame.origin.x = boundingFrame.minX
        return frame
    }

    init(tabViewModel: TabViewModel, addressBar: NSView?, delegate: NSPopoverDelegate?) {
        self.tabViewModel = tabViewModel
        self.addressBar = addressBar
        super.init()

        self.animates = false
        self.behavior = .semitransient
        self.delegate = delegate

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: ZoomPopoverViewController { contentViewController as! ZoomPopoverViewController }
    // swiftlint:enable force_cast

    private var isMouseLocationInsideButtonOrContentViewBounds: Bool {
        contentViewController?.view.isMouseLocationInsideBounds() == true || positioningView?.isMouseLocationInsideBounds() == true
    }

    private func setupContentController() {
        let controller = ZoomPopoverViewController(viewModel: ZoomPopoverViewModel(tabViewModel: tabViewModel))
        controller.delegate = self
        contentViewController = controller
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        if let addressBar {
            let frame = positioningView.convert(positioningRect, to: addressBar)
            offsetX = -max(24 - frame.minX, 0)
        }
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)

        // auto-close the popover after X seconds when mouse is out from the popover or Zoom button
        if let positioningView = positioningView as? MouseOverButton {
            positioningViewIsMouseOverCancellable = positioningView.observe(\.isMouseOver) { [weak self] _, _ in
                self?.isMouseOverDidChange()
            }
        } else {
            assertionFailure("\(positioningView) expected to be MouseOverButton to observe its isMouseOver state")
        }
    }

    func scheduleCloseTimer(source: Source) {
        self.source = source
        autoCloseCancellables = []

        // don‘t close while mouse is inside bounds
        guard !isMouseLocationInsideButtonOrContentViewBounds else { return }

        // close after interval for the [menu|toolbar] source
        if let hideUiInterval, hideUiInterval > 0 {
            let timer = Timer.scheduledTimer(withTimeInterval: hideUiInterval, repeats: false) { [weak self] _ in
                self?.close()
            }
            autoCloseCancellables.insert(AnyCancellable { timer.invalidate() })
        }
        // close when scrolling elsewhere
        NSEvent.publisher(forEvents: .local, matching: .scrollWheel)
            .sink { [weak self] event in
                guard let self,
                      let window = event.window,
                      let contentView = window.contentView,
                      let pointInView = contentView.mouseLocationInsideBounds(event.locationInWindow),
                      let scrolledView = contentView.hitTest(pointInView),
                      scrolledView is WKWebView else { return }

                self.close()
            }
            .store(in: &autoCloseCancellables)
    }

    /// Restart close timer on zoom level change while open
    func rescheduleCloseTimerIfNeeded() {
        if let source, !isMouseLocationInsideButtonOrContentViewBounds {
            scheduleCloseTimer(source: source)
        }
    }

    func isMouseOverDidChange() {
        if !isShown || isMouseLocationInsideButtonOrContentViewBounds {
            invalidateCloseTimer()
        } else {
            rescheduleCloseTimerIfNeeded()
        }
    }

    private func invalidateCloseTimer() {
        autoCloseCancellables = []
    }

    override func close() {
        invalidateCloseTimer()
        super.close()
    }

}

// TODO: ---vvv--- the following to be removed after Ship Review is done --vvv--
private extension NSUserInterfaceItemIdentifier {
    static let menuCloseIntervalItem = NSUserInterfaceItemIdentifier("menuCloseIntervalItem")
    static let toolbarCloseIntervalItem = NSUserInterfaceItemIdentifier("toolbarCloseIntervalItem")
}
private extension UserDefaultsWrapperKey {
    static let zoomToolbarHideUiInterval = Self(rawValue: "zoom_toolbar_hide_ui_interval")
    static let zoomMenuHideUiInterval = Self(rawValue: "zoom_menu_hide_ui_interval")
}
final class ZoomPopoverDebugMenu: NSMenu {

    @UserDefaultsWrapper(key: .zoomToolbarHideUiInterval, defaultValue: ZoomPopover.Constants.defaultToolbarHideUiInterval)
    private var zoomToolbarHideUiInterval: TimeInterval

    @UserDefaultsWrapper(key: .zoomMenuHideUiInterval, defaultValue: ZoomPopover.Constants.defaultMenuHideUiInterval)
    private var zoomMenuHideUiInterval: TimeInterval

    init() {
        super.init(title: "")

        buildItems {
            NSMenuItem(title: "Close Interval – Menu") {
                NSMenuItem(title: "0.5s", action: #selector(menuHideIntervalSelected), target: self, representedObject: NSNumber(0.5))
                NSMenuItem(title: "1s", action: #selector(menuHideIntervalSelected), target: self, representedObject: NSNumber(1))
                NSMenuItem(title: "2s", action: #selector(menuHideIntervalSelected), target: self, representedObject: NSNumber(2))
                NSMenuItem(title: "3s", action: #selector(menuHideIntervalSelected), target: self, representedObject: NSNumber(3))
                NSMenuItem(title: "4s", action: #selector(menuHideIntervalSelected), target: self, representedObject: NSNumber(4))
                NSMenuItem(title: "5s", action: #selector(menuHideIntervalSelected), target: self, representedObject: NSNumber(5))
                NSMenuItem.separator()
                NSMenuItem(title: "No auto-hide", action: #selector(menuHideIntervalSelected), target: self, representedObject: NSNumber(-1))
            }.withIdentifier(.menuCloseIntervalItem)

            NSMenuItem(title: "Close Interval – Toolbar") {
                NSMenuItem(title: "0.5s", action: #selector(toolbarHideIntervalSelected), target: self, representedObject: NSNumber(0.5))
                NSMenuItem(title: "1s", action: #selector(toolbarHideIntervalSelected), target: self, representedObject: NSNumber(1))
                NSMenuItem(title: "2s", action: #selector(toolbarHideIntervalSelected), target: self, representedObject: NSNumber(2))
                NSMenuItem(title: "3s", action: #selector(toolbarHideIntervalSelected), target: self, representedObject: NSNumber(3))
                NSMenuItem(title: "4s", action: #selector(toolbarHideIntervalSelected), target: self, representedObject: NSNumber(4))
                NSMenuItem(title: "5s", action: #selector(toolbarHideIntervalSelected), target: self, representedObject: NSNumber(5))
                NSMenuItem.separator()
                NSMenuItem(title: "No auto-hide", action: #selector(toolbarHideIntervalSelected), target: self, representedObject: NSNumber(-1))
            }.withIdentifier(.toolbarCloseIntervalItem)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Menu State Update

    override func update() {
        for item in item(with: .menuCloseIntervalItem)?.submenu?.items ?? [] {
            item.state = (zoomMenuHideUiInterval == ((item.representedObject as? NSNumber)?.doubleValue ?? 0)) ? .on: .off
        }
        for item in item(with: .toolbarCloseIntervalItem)?.submenu?.items ?? [] {
            item.state = (zoomToolbarHideUiInterval == ((item.representedObject as? NSNumber)?.doubleValue ?? 0)) ? .on: .off
        }
    }

    @objc func menuHideIntervalSelected(_ sender: NSMenuItem) {
        guard let interval = (sender.representedObject as? NSNumber)?.doubleValue else {
            fatalError("Unexpected \(sender.representedObject.map(String.init(describing:)) ?? "<nil>") expected NSNumber")
        }
        zoomMenuHideUiInterval = interval
    }

    @objc func toolbarHideIntervalSelected(_ sender: NSMenuItem) {
        guard let interval = (sender.representedObject as? NSNumber)?.doubleValue else {
            fatalError("Unexpected \(sender.representedObject.map(String.init(describing:)) ?? "<nil>") expected NSNumber")
        }
        zoomToolbarHideUiInterval = interval
    }

}
