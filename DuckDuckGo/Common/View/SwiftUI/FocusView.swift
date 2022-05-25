//
//  FocusView.swift
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

import Foundation
import AppKit
import Combine
import SwiftUI

final class FocusView: NSView {

    var shouldDrawFocusRing = false
    var shouldActivateOnMouseDown = true
    var defaultAction: (() -> Void)?
    var copyHandler: (() -> Void)?
    var onKeyDown: ((NSEvent) -> NSEvent?)?
    var onAppear: ((FocusView) -> Void)?
    var onDisappear: ((FocusView) -> Void)?
    var onFocus: ((FocusView, Bool) -> Void)? {
        didSet {
            setupFirstResponderObserver()
        }
    }

    private var firstResponderObserver: NSKeyValueObservation?

    private var _tag: Int
    override var tag: Int {
        get {
            return _tag
        }
        set {
            _tag = newValue
        }
    }

    var cornerRadius: CGFloat = 4

    init(tag: Int, frame: NSRect = .zero) {
        self._tag = tag
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isFirstResponder: Bool {
        self.window?.firstResponder === self
    }

    override var acceptsFirstResponder: Bool {
        NSApp.isFullKeyboardAccessEnabled && self.isVisible
    }

    override var canBecomeKeyView: Bool {
        NSApp.isFullKeyboardAccessEnabled && self.isVisible
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if shouldActivateOnMouseDown,
           case .leftMouseDown = NSApp.currentEvent?.type,
           isMouseLocationInsideBounds() {
            self.makeMeFirstResponder()
        }
        return nil
    }

    override var focusRingMaskBounds: NSRect {
        guard shouldDrawFocusRing else { return super.focusRingMaskBounds }
        return self.bounds
    }

    override func drawFocusRingMask() {
        guard shouldDrawFocusRing else { return }
        NSBezierPath(roundedRect: self.bounds, xRadius: cornerRadius, yRadius: cornerRadius)
            .fill()
    }

    @objc func performClick(_ sender: Any) {
        defaultAction?()
    }

    @objc func copy(_ sender: Any) {
        copyHandler?()
    }

    override func keyDown(with event: NSEvent) {
        var event: NSEvent! = event
        if let onKeyDown = onKeyDown {
            event = onKeyDown(event)
            guard event != nil else { return }
        }
        super.keyDown(with: event)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        firstResponderObserver = nil
        // if removed from view hierarchy while first responder: notify
        if isFirstResponder, let onFocus = onFocus {
            onFocus(self, false)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil {
            setupFirstResponderObserver()
            onAppear?(self)
        } else {
            onDisappear?(self)
        }
    }

    private func setupFirstResponderObserver() {
        guard let onFocus = onFocus,
              self.window != nil
        else {
            firstResponderObserver = nil
            return
        }
        firstResponderObserver = self.window?.observe(\.firstResponder, options: [.initial, .new, .old]) { [weak self] _, change in
            guard let self = self else { return }
            if change.oldValue ?? nil !== self && change.newValue ?? nil === self {
                onFocus(self, true)
            } else if change.oldValue ?? nil === self && change.newValue ?? nil !== self {
                onFocus(self, false)
            }
        }
    }

}

struct FocusSwiftUIView: NSViewRepresentable {

    var onClick: Bool
    var focusRing: Bool
    var tag: Int
    var cornerRadius: CGFloat?
    var onFocus: ((Bool) -> Void)?
    var onViewFocused: ((FocusView) -> Void)?
    var onAppear: ((FocusView) -> Void)?
    var action: (() -> Void)?
    var menu: (() -> NSMenu)?
    var onCopy: (() -> Void)?
    var keyDown: ((NSEvent) -> NSEvent?)?

    func makeNSView(context: Context) -> FocusView {
        let view = FocusView(tag: tag)
        updateNSView(view, context: context)

        return view
    }

    func updateNSView(_ view: FocusView, context: Context) {
        if let action = action {
            view.defaultAction = action
        } else if let menu = menu {
            view.menu = menu()
            view.defaultAction = { [weak view] in
                view?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: view)
            }
        }
        view.shouldDrawFocusRing = focusRing
        view.shouldActivateOnMouseDown = onClick
        view.copyHandler = onCopy
        view.onKeyDown = keyDown
        view.onFocus = onFocusHandler()
        view.tag = tag
        view.cornerRadius = cornerRadius ?? 4
        view.onAppear = onAppear
        view.onDisappear = { view in
            view.defaultAction = nil
            view.copyHandler = nil
            view.onKeyDown = nil
            view.onAppear = nil
        }

        if let onAppear = onAppear,
           view.window != nil {
            onAppear(view)
        }
    }

    private func onFocusHandler() -> ((FocusView, Bool) -> Void)? {
        guard onFocus != nil || onViewFocused != nil else { return nil }
        return { [onFocus, onViewFocused] view, isFirstResponder in
            onFocus?(isFirstResponder)
            if isFirstResponder {
                onViewFocused?(view)
            }
        }
    }

}
