//
//  NSColorExtension.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

extension NSColor {

    public var brightness: CGFloat {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return 0.5
        }
        return 0.2126 * rgbColor.redComponent + 0.7152 * rgbColor.greenComponent + 0.0722 * rgbColor.blueComponent
    }

    public convenience init?(hex: String) {
        var hexString = hex.uppercased()

        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.count == 6 else {
            return nil
        }

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xff) / 255.0,
            green: CGFloat((rgb >> 8) & 0xff) / 255.0,
            blue: CGFloat((rgb >> 0) & 0xff) / 255.0,
            alpha: 1
        )
    }

    public func hex(includeAlpha: Bool = false) -> String {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return "#000000"
        }

        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))

        if includeAlpha {
            let alpha = Int(round(rgbColor.alphaComponent * 255))
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        } else {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
    }

}
