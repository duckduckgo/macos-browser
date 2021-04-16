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

final class ColorView: NSView {

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupView()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setupView()
    }

    @IBInspectable var backgroundColor: NSColor? = NSColor.clear {
        didSet {
            layer?.backgroundColor = backgroundColor?.cgColor
        }
    }

    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer!.cornerRadius = cornerRadius
            layer!.masksToBounds = true
        }
    }

    @IBInspectable var borderColor: NSColor? = nil {
        didSet {
            layer!.borderColor = borderColor?.cgColor
        }
    }

    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer?.borderWidth = borderWidth
        }
    }

    func setupView() {
        self.wantsLayer = true
    }
    
    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = backgroundColor?.cgColor
        layer?.borderColor = borderColor?.cgColor
    }

    // MARK: - NSResponder Propogation

    // ColorView is frequently used as a background view, and should not pass touch events onto the views behind it.
    // By providing empty implementations of these NSResponder methods, the events are prevented from propogating through the responder chain.

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseDragged(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}

    override func mouseMoved(with event: NSEvent) {}
}
