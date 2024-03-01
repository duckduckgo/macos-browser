//
//  NSBezierPathExtension.swift
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

import AppKit

// MARK: Convert to CGPath

extension NSBezierPath {

    func asCGPath() -> CGPath {
        if #available(macOS 14.0, *) {
            return self.cgPath
        } else {
            let path = CGMutablePath()
            var points = [CGPoint](repeating: .zero, count: 3)
            for i in 0 ..< self.elementCount {
                let type = self.element(at: i, associatedPoints: &points)
                switch type {
                case .moveTo:
                    path.move(to: points[0])
                case .lineTo:
                    path.addLine(to: points[0])
                case .curveTo, .cubicCurveTo:
                    path.addCurve(to: points[2], control1: points[0], control2: points[1])
                case .quadraticCurveTo:
                    path.addQuadCurve(to: points[1], control: points[0])
                case .closePath:
                    path.closeSubpath()
                @unknown default:
                    break
                }
            }
            return path
        }
    }

}

// MARK: Optional rounded corners

extension NSBezierPath {

    enum Corners: CaseIterable {

        case topLeft, topRight, bottomLeft, bottomRight

    }

    convenience init(roundedRect rect: CGRect, forCorners corners: [Corners], cornerRadius: CGFloat) {
        self.init()

        /*
                 1      2
           c4     _______   c1
                 /       \
               8 |       | 3
                 |       |
               7 |       | 4
           c3    \_______/   c2
                 6       5
         */

        func addCorner(_ rounded: Bool, _ cornerPoint: CGPoint, _ nextPoint: CGPoint) {
            if rounded {
                appendArc(from: cornerPoint, to: nextPoint, radius: cornerRadius)
            } else {
                line(to: cornerPoint)
                line(to: nextPoint)
            }
        }

        let adjustedWidth = max(0, rect.width - cornerRadius * 2)
        let adjustedHeight = max(0, rect.height - cornerRadius * 2)

        let p1 = rect.origin.adjustingX(cornerRadius)
        let p2 = p1.adjustingX(adjustedWidth)
        let p3 = p2.adjustingX(cornerRadius).adjustingY(cornerRadius)
        let p4 = p3.adjustingY(adjustedHeight)
        let p5 = p4.adjustingX(-cornerRadius).adjustingY(cornerRadius)
        let p6 = p5.adjustingX(-adjustedWidth)
        let p7 = p6.adjustingY(-cornerRadius).adjustingX(-cornerRadius)
        let p8 = p7.adjustingY(-adjustedHeight)

        let c1 = p2.adjustingX(cornerRadius)
        let c2 = p4.adjustingY(cornerRadius)
        let c3 = p6.adjustingX(-cornerRadius)
        let c4 = p8.adjustingY(-cornerRadius)

        move(to: p1)
        line(to: p2)

        addCorner(corners.contains(.topRight), c1, p3)

        line(to: p3)
        line(to: p4)

        addCorner(corners.contains(.bottomRight), c2, p5)

        line(to: p5)
        line(to: p6)

        addCorner(corners.contains(.bottomLeft), c3, p7)

        line(to: p7)
        line(to: p8)

        addCorner(corners.contains(.topLeft), c4, p1)
    }

}

fileprivate extension CGPoint {

    func adjustingX(_ offset: CGFloat) -> CGPoint {
        return CGPoint(x: x + offset, y: y)
    }

    func adjustingY(_ offset: CGFloat) -> CGPoint {
        return CGPoint(x: x, y: y + offset)
    }

}
