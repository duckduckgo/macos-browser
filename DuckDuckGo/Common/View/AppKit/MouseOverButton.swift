//
//  MouseOverButton.swift
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
import Carbon.HIToolbox

internal class MouseOverButton: NSButton {

    let backgroundLayer = CALayer()

    @IBInspectable var mouseOverColor: NSColor? {
        didSet {
            updateLayer()
        }
    }
    @IBInspectable var mouseDownColor: NSColor? {
        didSet {
            updateLayer()
        }
    }

    var normalTintColor: NSColor? {
        didSet {
            updateTintColor()
        }
    }
    @IBInspectable var mouseOverTintColor: NSColor? {
        didSet {
            updateTintColor()
        }
    }
    @IBInspectable var mouseDownTintColor: NSColor? {
        didSet {
            updateTintColor()
        }
    }

    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            updateLayer()
        }
    }

    @IBInspectable var contentInset: NSPoint = .zero {
        didSet {
            updateLayer()
        }
    }

    @IBInspectable var shouldAppearOnFocus: Bool = false
    @IBInspectable var focusable: Bool = true

    override var isEnabled: Bool {
        didSet {
            updateLayer()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    private func initialize() {
        self.setButtonType(.momentaryPushIn)
        self.isBordered = false
        self.bezelStyle = .shadowlessSquare

        configureLayers()
    }

    private func configureLayers() {
        self.wantsLayer = true
        self.layerUsesCoreImageFilters = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.backgroundLayer.masksToBounds = true
        self.layer?.addSublayer(backgroundLayer)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)

        isMouseDown = false
        isMouseOver = false

        if newWindow != nil {
            normalTintColor = self.contentTintColor
            addTrackingArea()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseOver = true
    }

    override func mouseExited(with event: NSEvent) {
        isMouseOver = false
    }

    override func mouseDown(with event: NSEvent) {
        isMouseDown = true
        super.mouseDown(with: event)
        isMouseDown = false
        if isMouseOver,
           NSApp.keyWindow !== window || isMouseLocationInsideBounds(window?.mouseLocationOutsideOfEventStream) != true {

            mouseExited(with: event)
        }
    }

    @Published private(set) var isMouseOver = false {
        didSet {
            updateTintColor()
            updateLayer()
        }
    }

    var isMouseDown = false {
        didSet {
            updateTintColor()
            updateLayer()
        }
    }

    func updateTintColor() {
        NSAppearance.withAppAppearance {
            if isMouseDown {
                self.contentTintColor = self.mouseDownTintColor ?? self.normalTintColor
            } else if isMouseOver {
                self.contentTintColor = self.mouseOverTintColor ?? self.normalTintColor
            } else {
                self.contentTintColor = self.normalTintColor
            }
        }
    }

    override func updateLayer() {
        backgroundLayer.cornerRadius = cornerRadius
        backgroundLayer.frame = layer!.bounds.insetBy(dx: contentInset.x, dy: contentInset.y)

        guard isEnabled else {
            backgroundLayer.backgroundColor = NSColor.clear.cgColor
            return
        }

        NSAppearance.withAppAppearance {
            NSAnimationContext.runAnimationGroup { context in
                if isMouseDown {
                    context.duration = 0.0
                    backgroundLayer.backgroundColor = mouseDownColor?.cgColor ?? NSColor.clear.cgColor
                } else if isMouseOver {
                    context.duration = 0.0
                    backgroundLayer.backgroundColor = mouseOverColor?.cgColor ?? NSColor.clear.cgColor
                } else {
                    backgroundLayer.backgroundColor = NSColor.clear.cgColor
                }
            }
        }
    }

    private func addTrackingArea() {
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func drawFocusRingMask() {
        switch focusRingType {
        case .exterior:
            NSBezierPath(roundedRect: self.bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        case .none:
            return
        case .default: fallthrough
        @unknown default:
            super.drawFocusRingMask()
        }
    }

    override var canBecomeKeyView: Bool {
        guard focusable else { return false }
        return super.canBecomeKeyView
            || (NSApp.isFullKeyboardAccessEnabled && self.shouldAppearOnFocus)
    }

    override var acceptsFirstResponder: Bool {
        guard focusable else { return false }
        return super.acceptsFirstResponder
            || (NSApp.isFullKeyboardAccessEnabled && self.shouldAppearOnFocus)
    }

    override var isHidden: Bool {
        get {
            super.isHidden
        }
        set {
            if isDisplayedOnFocus {
                if newValue == false {
                    super.isHidden = false
                    self.isDisplayedOnFocus = false
                }
                return
            } else if self.isFirstResponder && newValue == true {
                self.isDisplayedOnFocus = true
                return
            }
            super.isHidden = newValue
        }
    }

    private var isDisplayedOnFocus = false
    override func becomeFirstResponder() -> Bool {
        if self.isHidden && self.shouldAppearOnFocus {
            self.isHidden = false
            self.isDisplayedOnFocus = true
        }

        guard super.becomeFirstResponder() else {
            if isDisplayedOnFocus {
                self.isDisplayedOnFocus = false
                super.isHidden = true
            }
            return false
        }

        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }

        if self.isDisplayedOnFocus {
            self.isDisplayedOnFocus = false
            super.isHidden = true
        }

        return true
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Space,
             // show menu on Arrow Down
             kVK_DownArrow where self.sendActionOn == .leftMouseDown:

            self.sendAction(self.action, to: self.target)

        default:
            super.keyDown(with: event)
        }
    }

}
