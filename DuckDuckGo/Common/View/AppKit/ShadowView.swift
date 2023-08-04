//
//  ShadowView.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class ShadowView: NSView {

    struct ShadowSide: OptionSet {
        let rawValue: UInt8

        static let left   = ShadowSide(rawValue: 1 << 0)
        static let top    = ShadowSide(rawValue: 1 << 1)
        static let right  = ShadowSide(rawValue: 1 << 2)
        static let bottom = ShadowSide(rawValue: 1 << 3)

        static let all    = ShadowSide(rawValue: 0xF)
    }

    @IBInspectable var shadowColor: NSColor? {
        didSet {
            self.needsDisplay = true
        }
    }
    @IBInspectable var shadowRadius: CGFloat = 0 {
        didSet {
            self.needsDisplay = true
            self.needsLayout = true
        }
    }
    @IBInspectable var shadowOffset: CGSize = .zero {
        didSet {
            self.needsDisplay = true
            self.needsLayout = true
        }
    }
    @IBInspectable var shadowOpacity: CGFloat = 0 {
        didSet {
            self.needsDisplay = true
        }
    }
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            self.needsDisplay = true
            self.needsLayout = true
        }
    }
    var shadowSides: ShadowSide = .all {
        didSet {
            self.needsLayout = true
        }
    }

    lazy private var mask: CAShapeLayer = {
        let mask = CAShapeLayer()
        mask.fillRule = CAShapeLayerFillRule.evenOdd
        layer!.mask = mask
        return mask
    }()

    private func shadowPath() -> CGPath {
        let cornerRadius: CGFloat = min(min(bounds.width, bounds.height) / 2, self.cornerRadius)
        let shadowPath = CGMutablePath()

        func corner(_ tangent1: CGPoint, _ tangent2: CGPoint, for sides: ShadowSide) {
            if cornerRadius > 0 {
                if sides.subtracting(shadowSides).isEmpty {

                    shadowPath.addArc(tangent1End: tangent1, tangent2End: tangent2, radius: cornerRadius)
                } else {
                    shadowPath.addLine(to: tangent1)
                    shadowPath.addLine(to: tangent2)
                }
            } else {
                shadowPath.addLine(to: tangent2)
            }
        }

        shadowPath.move(to: CGPoint(x: bounds.minX + cornerRadius, y: bounds.minY))

        corner(CGPoint(x: bounds.minX, y: bounds.minY),
               CGPoint(x: bounds.minX, y: bounds.minY + cornerRadius),
               for: [.left, .bottom])
        shadowPath.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY - cornerRadius))

        corner(CGPoint(x: bounds.minX, y: bounds.maxY),
               CGPoint(x: bounds.minX + cornerRadius, y: bounds.maxY),
               for: [.left, .top])
        shadowPath.addLine(to: CGPoint(x: bounds.maxX - cornerRadius, y: bounds.maxY))

        corner(CGPoint(x: bounds.maxX, y: bounds.maxY),
               CGPoint(x: bounds.maxX, y: bounds.maxY - cornerRadius),
               for: [.right, .top])
        shadowPath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + cornerRadius))

        corner(CGPoint(x: bounds.maxX, y: bounds.minY),
               CGPoint(x: bounds.maxX - cornerRadius, y: bounds.minY),
               for: [.right, .bottom])
        shadowPath.addLine(to: CGPoint(x: bounds.minX + cornerRadius, y: bounds.minY))

        return shadowPath
    }

    private func maskPath(shadowPath: CGPath) -> CGPath {
        let dx = (shadowRadius + abs(shadowOffset.width)) * 2
        let dy = (shadowRadius + abs(shadowOffset.height)) * 2

        var outerRect = bounds
        if shadowSides.contains(.left) {
            outerRect.origin.x -= dx
            outerRect.size.width += dx
        }
        if shadowSides.contains(.right) {
            outerRect.size.width += dx
        }
        if shadowSides.contains(.bottom) {
            outerRect.origin.y -= dy
            outerRect.size.height += dy
        }
        if shadowSides.contains(.top) {
            outerRect.size.height += dy
        }

        let maskPath = CGMutablePath(rect: outerRect, transform: nil)
        maskPath.addPath(shadowPath)

        return maskPath
    }

    override func layout() {
        super.layout()

        let shadowPath = self.shadowPath()
        layer!.shadowPath = shadowPath

        mask.path = self.maskPath(shadowPath: shadowPath)
    }

    override func updateLayer() {
        super.updateLayer()

        updateProperties()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard case .some = window else { return }
        updateProperties()
    }

    private func updateProperties() {
        self.wantsLayer = true

        layer!.masksToBounds = false
        layer!.backgroundColor = NSColor.clear.cgColor
        layer!.cornerRadius = cornerRadius
        layer!.shadowColor = shadowColor?.cgColor
        layer!.shadowRadius = shadowRadius
        layer!.shadowOffset = shadowOffset
        layer!.shadowOpacity = Float(shadowOpacity)
    }

}
