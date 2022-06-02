//
//  TabBarCellView.swift
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

final class TabBarCellView: NSView {

    override var canBecomeKeyView: Bool {
        NSApp.isFullKeyboardAccessEnabled
    }

    override var acceptsFirstResponder: Bool {
        NSApp.isFullKeyboardAccessEnabled
    }

    private var isFirstResponderCancellable: AnyCancellable?
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewDidMoveToWindow()

        isFirstResponderCancellable = newWindow?.publisher(for: \.firstResponder).map { [weak self] firstResponder in
            return firstResponder === self
        }.assign(to: \.isFirstResponder, onWeaklyHeld: self)
    }

    var isFirstResponder: Bool = false {
        didSet {
            guard isFirstResponder != oldValue else { return }
            if isFirstResponder {
                didBecomeFirstResponder()
            } else {
                didResignFirstResponder()
            }
        }
    }

    private func didBecomeFirstResponder() {
        setAccessibilityFocused(true)
        showFocusRing()
    }

    private func didResignFirstResponder() {
        setAccessibilityFocused(false)
        DispatchQueue.main.async { [weak self] in
            guard (self?.window?.firstResponder is TabBarCellView) != true else {
                return
            }
            self?.removeFocusRing()
        }
    }

    private func focusRingClipView(createIfNeeded: Bool) -> FocusRingClipView? {
        let scrollView = enclosingScrollView
        let themeFrameView = window?.themeFrameView
        if let focusRingClipView = themeFrameView?.subviews.first(where: { $0 is FocusRingClipView }) as? FocusRingClipView {
            return focusRingClipView
        }
        guard createIfNeeded else { return nil }

        let focusRingClipView = FocusRingClipView(overlaidView: scrollView)
        themeFrameView?.addSubview(focusRingClipView)

        return focusRingClipView
    }

    private func focusRingView(createIfNeeded: Bool) -> ShadowView? {
        let focusRingClipView = self.focusRingClipView(createIfNeeded: createIfNeeded)

        if let focusRingView = focusRingClipView?.subviews.first(where: { $0 is ShadowView }) as? ShadowView {
            return focusRingView
        }
        guard createIfNeeded else { return nil }

        let focusRingView = ShadowView()
        focusRingView.stroke = 2
        focusRingView.shadowColor = NSColor.controlAccentColor
        focusRingView.shadowRadius = 0
        focusRingView.cornerRadius = 6
        focusRingView.shadowOpacity = 1.0
        focusRingView.shouldHideOnLostFocus = true
        focusRingView.isHidden = true

        focusRingClipView?.addSubview(focusRingView)
        return focusRingView
    }

    private func showFocusRing() {
        guard let scrollView = enclosingScrollView,
              let focusRing = self.focusRingView(createIfNeeded: true)
        else {
            return
        }

        self.updateFocusRingFrame()
        self.observeScrollPosition(in: scrollView)
        focusRing.isHidden = false
    }

    private func updateFocusRingFrame() {
        if self.window?.firstResponder === self,
           let focusRingView = self.focusRingView(createIfNeeded: false) {
            focusRingView.frame = self.convert(self.bounds, to: focusRingView.superview)

        } else if let scrollPositionObserver = scrollPositionObserver {
            NotificationCenter.default.removeObserver(scrollPositionObserver)
            self.scrollPositionObserver = nil
        }
    }

    private var scrollPositionObserver: Any?
    private func observeScrollPosition(in scrollView: NSScrollView) {
        scrollView.postsBoundsChangedNotifications = true
        scrollPositionObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                                        object: scrollView.contentView,
                                                                        queue: nil) { [weak self] _ in
            self?.updateFocusRingFrame()
        }
    }

    override func layout() {
        super.layout()
        updateFocusRingFrame()
    }

    private func removeFocusRing() {
        focusRingView(createIfNeeded: false)?.isHidden = true
    }

    override func accessibilityFrame() -> NSRect {
        let frame = self.window != nil ? super.accessibilityFrame() : self.frame
        guard let parent = self.accessibilityParent() as? NSAccessibilityProtocol else { return frame }

        let parentFrame = parent.accessibilityFrame()
        let intersection = parentFrame.intersection(frame)

        // display thin line at the TabBar edge instead of real frame if out of scroll view
        if intersection.isEmpty || self.window == nil {
            let isOnLeft = self.window != nil ? (frame.minX < parentFrame.minX) : frame.origin.x <= 0
            return NSRect(x: isOnLeft ? parentFrame.minX : parentFrame.maxX - 2,
                          y: parentFrame.origin.y,
                          width: 2,
                          height: parentFrame.height)
        }
        return intersection
    }

    override func accessibilityChildren() -> [Any]? {
        self.subviews.compactMap { subview in
            guard let button = subview as? NSButton,
                  !button.isHidden || button.action == #selector(TabBarViewItem.close(_:))
            else { return nil }
            return button.cell
        }
    }

    override func accessibilityPerformPress() -> Bool {
        NSApp.sendAction(#selector(TabBarViewItem.performClick(_:)), to: nextResponder, from: self)
    }

    override func accessibilityPerformDelete() -> Bool {
        NSApp.sendAction(#selector(TabBarViewItem.close(_:)), to: nextResponder, from: self)
    }

}

private final class FocusRingClipView: NSView {

    private weak var overlaidView: NSView?
    private var frameCancellable: AnyCancellable?
    init(overlaidView: NSView?) {
        self.overlaidView = overlaidView
        super.init(frame: overlaidView?.bounds ?? .zero)

        self.wantsLayer = true
        self.layer!.cornerRadius = 12.0
        self.autoresizingMask = [.width, .minYMargin]
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            frameCancellable = nil
            return
        }

        frameCancellable = overlaidView?.publisher(for: \.frame).sink { [weak overlaidView, weak self] frame in
            guard let self = self,
                  let overlaidViewSuperview = overlaidView?.superview,
                  let frame = overlaidView?.frame,
                  let superview = self.superview
            else { return }
            self.frame = overlaidViewSuperview.convert(frame, to: superview).insetBy(dx: -2, dy: -6)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

}
