//
//  MouseOverView.swift
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

class MouseOverView: NSView {

    @IBInspectable var mouseOverColor: NSColor? {
        didSet {
            setBackgroundColor()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        layerUsesCoreImageFilters = true
        addTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseOver = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseOver = false
        super.mouseExited(with: event)
    }

    private var isMouseOver = false {
        didSet {
            setBackgroundColor()
        }
    }

    private func setBackgroundColor() {
        guard let mouseOverColor = mouseOverColor else {
            layer?.backgroundColor = NSColor.clear.cgColor
            return
        }

        if isMouseOver {
            layer?.backgroundColor = mouseOverColor.cgColor
        } else {
//            if layer?.backgroundColor == mouseOverColor.cgColor {
//                print("layer?.backgroundColor \(layer?.backgroundColor)")
//                let animation = CABasicAnimation(keyPath: "backgroundColor")
//                animation.fromValue = layer?.backgroundColor
//                animation.toValue = NSColor.clear.cgColor
//                animation.duration = 1/5

                layer?.backgroundColor = NSColor.clear.cgColor
//                layer?.add(animation, forKey: "backgroundColor")
//            }
        }
    }

    private func addTrackingArea() {
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
}
