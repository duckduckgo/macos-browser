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

    func setView(firstResponder: Bool, animated: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 1/3 : 0)

        shadowLayer.opacity = firstResponder ? 0.4 : 0
        strokeLayer.opacity = firstResponder ? 1.0 : 0
        backgroundLayer.backgroundColor = firstResponder ?
                NSColor.textBackgroundColor.cgColor : NSColor(named: "AddressBarBackgroundColor")?.cgColor
        
        CATransaction.commit()
    }

    private func addSublayers() {
        shadowLayer.backgroundColor = NSColor(named: "AddressBarAccentColor")?.cgColor
        shadowLayer.opacity = 0
        layer?.addSublayer(shadowLayer)

        strokeLayer.backgroundColor = NSColor(named: "AddressBarAccentColor")?.cgColor
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
        shadowLayer.frame = layer.bounds
        shadowLayer.cornerRadius = shadowLayer.frame.height / 2
        strokeLayer.frame = NSRect(x: layer.bounds.origin.x + 3,
                                   y: layer.bounds.origin.y + 3,
                                   width: layer.bounds.size.width - 6,
                                   height: layer.bounds.size.height - 6)
        strokeLayer.cornerRadius = strokeLayer.frame.height / 2
        backgroundLayer.frame = NSRect(x: layer.bounds.origin.x + 3.5,
                                       y: layer.bounds.origin.y + 3.5,
                                       width: layer.bounds.size.width - 7,
                                       height: layer.bounds.size.height - 7)
        backgroundLayer.cornerRadius = backgroundLayer.frame.height / 2
        CATransaction.commit()
    }
    
}
