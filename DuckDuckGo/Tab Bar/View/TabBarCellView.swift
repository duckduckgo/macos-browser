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

final class TabBarCellView: NSView {

    override var canBecomeKeyView: Bool {
        NSApp.isFullKeyboardAccessEnabled
    }

    override var acceptsFirstResponder: Bool {
        NSApp.isFullKeyboardAccessEnabled
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }

        setAccessibilityFocused(true)
        showFocusRing()
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }

        setAccessibilityFocused(false)
        removeFocusRing()
        return true
    }

    private func focusRingClipView(createIfNeeded: Bool) -> FocusRingClipView? {
        let scrollView = enclosingScrollView
        let themeFrameView = window?.themeFrameView
        if let focusRingClipView = themeFrameView?.subviews.first(where: { $0 is FocusRingClipView }) as? FocusRingClipView {
            return focusRingClipView
        }
        guard createIfNeeded else { return nil }

        let frame = scrollView?.superview?.convert(scrollView!.frame, to: themeFrameView).insetBy(dx: -2, dy: -6) ?? .zero
        let focusRingClipView = FocusRingClipView(frame: frame)
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

        var parentFrame = parent.accessibilityFrame()
        parentFrame = parentFrame.insetBy(dx: 0, dy: (parentFrame.height - frame.height) / 2)
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

    override func accessibilityPerformPress() -> Bool {
        NSApp.sendAction(#selector(TabBarViewItem.performClick(_:)), to: nextResponder, from: self)
    }

    override func accessibilityPerformDelete() -> Bool {
        NSApp.sendAction(#selector(TabBarViewItem.close(_:)), to: nextResponder, from: self)
    }

}

private final class FocusRingClipView: NSView {

    override init(frame: NSRect) {
        super.init(frame: frame)

        self.wantsLayer = true
        self.layer!.cornerRadius = 12.0
        self.autoresizingMask = [.width, .minYMargin]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

}
