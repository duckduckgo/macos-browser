//
//  AddressBarView.swift
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

class AddressBarView: NSView {

    enum Size: CGFloat {
        case shadow = 2.5
        case stroke = 0.5
        case backgroundRadius = 8
    }

    private let shadowLayer = CALayer()
    private let strokeLayer = CALayer()
    private let backgroundLayer = CALayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true

        addSublayers()
        layoutSublayers()
    }

    override func layout() {
        super.layout()

        layoutSublayers()
    }

    func updateView(stroke: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)

        shadowLayer.opacity = stroke ? 0.4 : 0
        strokeLayer.opacity = stroke ? 1.0 : 0
        backgroundLayer.backgroundColor = stroke ?
                NSColor.textBackgroundColor.cgColor : NSColor(named: "AddressBarBackgroundColor")?.cgColor
        
        CATransaction.commit()
    }

    private func addSublayers() {
        shadowLayer.opacity = 0
        layer?.addSublayer(shadowLayer)

        strokeLayer.opacity = 0
        layer?.addSublayer(strokeLayer)

        backgroundLayer.backgroundColor = NSColor(named: "AddressBarBackgroundColor")?.cgColor
        layer?.addSublayer(backgroundLayer)
    }

    private func layoutSublayers() {
        guard let layer = layer else {
            return
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0)

        // If the user changes the accent color this will get called and we need to refresh the color.
        shadowLayer.backgroundColor = NSColor.controlAccentColor.cgColor
        strokeLayer.backgroundColor = NSColor.controlAccentColor.cgColor

        shadowLayer.frame = layer.bounds
        shadowLayer.cornerRadius = Size.backgroundRadius.rawValue + Size.shadow.rawValue + Size.stroke.rawValue
        strokeLayer.frame = NSRect(x: layer.bounds.origin.x + Size.shadow.rawValue,
                                   y: layer.bounds.origin.y + Size.shadow.rawValue,
                                   width: layer.bounds.size.width - 2 * Size.shadow.rawValue,
                                   height: layer.bounds.size.height - 2 * Size.shadow.rawValue)
        strokeLayer.cornerRadius = Size.backgroundRadius.rawValue + Size.stroke.rawValue
        backgroundLayer.frame = NSRect(x: layer.bounds.origin.x + Size.shadow.rawValue + Size.stroke.rawValue,
                                       y: layer.bounds.origin.y + Size.shadow.rawValue + Size.stroke.rawValue,
                                       width: layer.bounds.size.width - 2 * (Size.shadow.rawValue + Size.stroke.rawValue),
                                       height: layer.bounds.size.height - 2 * (Size.shadow.rawValue + Size.stroke.rawValue))
        backgroundLayer.cornerRadius = Size.backgroundRadius.rawValue
        CATransaction.commit()
    }
    
}
