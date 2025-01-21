//
//  ColorView.swift
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

internal class ColorView: NSView {

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupView()
    }

    init(frame: NSRect, backgroundColor: NSColor? = nil, cornerRadius: CGFloat = 0, borderColor: NSColor? = nil, borderWidth: CGFloat = 0, interceptClickEvents: Bool = false) {
        super.init(frame: frame)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.interceptClickEvents = interceptClickEvents

        setupView()
    }

    @IBInspectable var backgroundColor: NSColor? = NSColor.clear {
        didSet {
            NSAppearance.withAppAppearance {
                layer?.backgroundColor = backgroundColor?.cgColor
            }
        }
    }

    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer!.cornerRadius = cornerRadius
            layer!.masksToBounds = true
        }
    }

    @IBInspectable var borderColor: NSColor? {
        didSet {
            NSAppearance.withAppAppearance {
                layer!.borderColor = borderColor?.cgColor
            }
        }
    }

    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer?.borderWidth = borderWidth
        }
    }

    @IBInspectable var interceptClickEvents: Bool = false

    func setupView() {
        self.wantsLayer = true
    }

    override func updateLayer() {
        super.updateLayer()
        NSAppearance.withAppAppearance {
            layer?.backgroundColor = backgroundColor?.cgColor
            layer?.borderColor = borderColor?.cgColor
        }
    }

    // MARK: - Click Event Interception

    override func mouseDown(with event: NSEvent) {
        if !interceptClickEvents {
            super.mouseDown(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !interceptClickEvents {
            super.mouseUp(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if !interceptClickEvents {
            super.mouseDragged(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if !interceptClickEvents {
            super.rightMouseDown(with: event)
        }
    }

    override func otherMouseDown(with event: NSEvent) {
        if !interceptClickEvents {
            super.otherMouseDown(with: event)
        }
    }
}
