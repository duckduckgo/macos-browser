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

class MouseOverButton: NSButton {

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        addTrackingArea()
        setCornerRadius()
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
    }

    @IBInspectable var mouseOverColor: NSColor?
    @IBInspectable var mouseDownColor: NSColor?
    @IBInspectable var cornerRadius: CGFloat = 0

    private var isMouseOver = false {
        didSet {
            setBackgroundColor()
        }
    }

    private var isMouseDown = false {
        didSet {
            setBackgroundColor()
        }
    }

    private func setBackgroundColor() {
        guard isEnabled else {
            layer?.backgroundColor = NSColor.clear.cgColor
            return
        }

        if isMouseDown {
            layer?.backgroundColor = self.mouseDownColor?.cgColor ?? NSColor.clear.cgColor
        } else if isMouseOver {
            layer?.backgroundColor = self.mouseOverColor?.cgColor ?? NSColor.clear.cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func addTrackingArea() {
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    private func setCornerRadius() {
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = cornerRadius > 0
    }

}
