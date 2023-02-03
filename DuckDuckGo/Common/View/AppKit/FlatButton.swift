//
//  FlatButton.swift
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

@IBDesignable class FlatButton: NSButton {

    @IBInspectable var cornerRadius: CGFloat = 5
    @IBInspectable var horizontalPadding: CGFloat = 10
    @IBInspectable var verticalPadding: CGFloat = 10
    @IBInspectable var backgroundColor: NSColor = .blue

    override func draw(_ dirtyRect: NSRect) {

        self.wantsLayer = true
        self.layer?.cornerRadius = cornerRadius

        if isHighlighted {
            layer?.backgroundColor = backgroundColor.blended(withFraction: 0.2, of: .black)?.cgColor
        } else {
            layer?.backgroundColor = backgroundColor.cgColor
        }

        let originalBounds = self.bounds
        defer { self.bounds = originalBounds }

        self.bounds = originalBounds.insetBy(dx: horizontalPadding, dy: verticalPadding)

        super.draw(dirtyRect)
    }
}
