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

internal class MouseOverButton: NSButton {

    let backgroundLayer = CALayer()

    @IBInspectable var backgroundColor: NSColor? {
        didSet {
            updateLayer()
        }
    }

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

    override var isEnabled: Bool {
        didSet {
            updateLayer()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configureLayers()
    }

    private func configureLayers() {
        self.wantsLayer = true
        self.layerUsesCoreImageFilters = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.backgroundLayer.masksToBounds = true
        self.layer?.addSublayer(backgroundLayer)
    }

    override func awakeFromNib() {
        normalTintColor = self.contentTintColor
        addTrackingArea()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        isMouseDown = false
        isMouseOver = false
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseOver = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseOver = false
    }

    override func mouseDown(with event: NSEvent) {
        isMouseDown = true
        super.mouseDown(with: event)
        isMouseDown = false
        if isMouseOver,
           window?.isKeyWindow != true || isMouseLocationInsideBounds(window?.mouseLocationOutsideOfEventStream) != true {

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
                    backgroundLayer.backgroundColor = backgroundColor?.cgColor ?? NSColor.clear.cgColor
                }
            }
        }
    }

    private func addTrackingArea() {
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

}
