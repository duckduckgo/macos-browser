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

    private var focusCancellable: AnyCancellable?

    var onFocus: ((Bool) -> Void)? {
        didSet {
            if let onFocus = onFocus {
                focusCancellable = self.isFirstResponderPublisher().sink(receiveValue: onFocus)
            } else {
                focusCancellable = nil
            }
        }
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
        NSBezierPath(roundedRect: self.bounds, xRadius: 4, yRadius: 4).fill()
    }

    @objc
    func performClick(_ sender: Any) {
        defaultAction?()
    }

    @objc
    func copy(_ sender: Any) {
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

}

struct FocusSwiftUIView: NSViewRepresentable {

    var onClick: Bool
    var focusRing: Bool
    var onFocus: ((Bool) -> Void)?
    var action: (() -> Void)?
    var menu: (() -> NSMenu)?
    var onCopy: (() -> Void)?
    var keyDown: ((NSEvent) -> NSEvent?)?

    func makeNSView(context: Context) -> FocusView {
        let view = FocusView()
        view.shouldDrawFocusRing = focusRing
        view.shouldActivateOnMouseDown = onClick
        if let action = action {
            view.defaultAction = action
        } else if let menu = menu {
            view.menu = menu()
            view.defaultAction = { [weak view] in
                view?.menu?.popUp(positioning: nil, at: .zero, in: view)
            }
        }
        view.copyHandler = onCopy
        view.onKeyDown = keyDown
        view.onFocus = onFocus

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
        view.copyHandler = onCopy
        view.onKeyDown = keyDown
        view.onFocus = onFocus
    }

}
