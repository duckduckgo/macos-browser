//
//  ColorExtensions.swift
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

import SwiftUI

public extension Color {

    init(hex: String) {
        var hexString = hex.uppercased()

        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0
        )
    }

    static func forString(_ string: String) -> Color {
        var consistentHash: Int {
            return string.utf8
                .map { return $0 }
                .reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
        }

        let palette = [
            Color(hex: "94B3AF"),
            Color(hex: "727998"),
            Color(hex: "645468"),
            Color(hex: "4D5F7F"),
            Color(hex: "855DB6"),
            Color(hex: "5E5ADB"),
            Color(hex: "678FFF"),
            Color(hex: "6BB4EF"),
            Color(hex: "4A9BAE"),
            Color(hex: "66C4C6"),
            Color(hex: "55D388"),
            Color(hex: "99DB7A"),
            Color(hex: "ECCC7B"),
            Color(hex: "E7A538"),
            Color(hex: "DD6B4C"),
            Color(hex: "D65D62")
        ]

        let hash = consistentHash
        let index = hash % palette.count
        return palette[abs(index)]
    }
}
