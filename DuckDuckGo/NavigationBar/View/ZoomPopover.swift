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
        /// Zoom UI auto-close interval when opened using the Zoom button in the Address Bar (`nil` if auto-close disabled)
        static let toolbarHideUiInterval: TimeInterval? = nil
        /// Auto-close interval when opened using an app (or ⋮ ) menu item or using ⌘+ / ⌘- shortcuts (`nil` if auto-close disabled)
        static let menuHideUiInterval: TimeInterval? = 2
    }

    private var tabViewModel: TabViewModel
    private weak var addressBar: NSView?
    private var positioningViewIsMouseOverCancellable: NSKeyValueObservation?
    private var autoCloseTimer: Timer? {
        willSet {
            autoCloseTimer?.invalidate()
        }
    }

    enum Source { case toolbar, menu }
    private var source: Source?

    private var hideUiInterval: TimeInterval? {
        let interval: TimeInterval? = switch source {
        case .toolbar:
            Constants.toolbarHideUiInterval
        case .menu:
            Constants.menuHideUiInterval
        case .none:
            nil
        }
        guard let interval, interval > 0 else { return nil } // no auto-hide
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
        self.autoCloseTimer = nil

        // don‘t close while mouse is inside bounds
        guard !isMouseLocationInsideButtonOrContentViewBounds else { return }

        // close after interval for the [menu|toolbar] source
        if let hideUiInterval, hideUiInterval > 0 {
            autoCloseTimer = Timer.scheduledTimer(withTimeInterval: hideUiInterval, repeats: false) { [weak self] _ in
                self?.close()
            }
        }
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
        autoCloseTimer = nil
    }

    override func close() {
        invalidateCloseTimer()
        super.close()
    }

}
