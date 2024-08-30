//
//  SolidColorBackground.swift
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

import AppKitExtensions
import SwiftUI

/**
 * This enum represents items in Solid Color background picker.
 *
 * The Solid Color background picker is slightly different than others because the first
 * item is a color picker, while the rest are predefined background colors.
 *
 * The picker's displayed color is provided by `SettingsModel`, while predefined colors are static.
 */
enum SolidColorBackgroundPickerItem: Hashable, Equatable, Identifiable, CustomBackgroundConvertible {
    case picker(SolidColorBackground)
    case background(SolidColorBackground)

    var customBackground: CustomBackground {
        switch self {
        case .picker(let background), .background(let background):
            return background.customBackground
        }
    }

    var id: Int {
        hashValue
    }
}

struct SolidColorBackground: Hashable, Equatable, Identifiable, LosslessStringConvertible, ColorSchemeProviding, CustomBackgroundConvertible {

    let color: NSColor
    let colorScheme: ColorScheme
    let predefinedColorName: String?

    init(color: NSColor, colorScheme: ColorScheme? = nil, predefinedColorName: String? = nil) {
        self.color = color
        self.colorScheme = colorScheme ?? (color.brightness > 0.5 ? .light : .dark)
        self.predefinedColorName = predefinedColorName
    }

    init?(_ description: String) {
        if let predefinedColor = Self.predefinedColorsMap[description] {
            self = predefinedColor
            return
        }
        guard let color = NSColor(hex: description) else {
            return nil
        }
        self.init(color: color)
    }

    /**
     * Use predefined name as description, otherwise fall back to color's hex representation.
     *
     * Predefined name is here in order to distinguish predefined colors from colors selected in a picker.
     */
    var description: String {
        predefinedColorName ?? color.hex(includeAlpha: false)
    }

    var id: Int {
        hashValue
    }

    var customBackground: CustomBackground {
        .solidColor(self)
    }

    static let predefinedColorsMap: [String: SolidColorBackground] = [
        "color01": .color01,
        "color02": .color02,
        "color03": .color03,
        "color04": .color04,
        "color05": .color05,
        "color06": .color06,
        "color07": .color07,
        "color08": .color08,
        "color09": .color09,
        "color10": .color10,
        "color11": .color11,
        "color12": .color12,
        "color13": .color13,
        "color14": .color14,
        "color15": .color15,
        "color16": .color16,
        "color17": .color17,
        "color18": .color18,
        "color19": .color19
    ]

    static let predefinedColors: [SolidColorBackground] = predefinedColorsMap.values
        .sorted(by: { ($0.predefinedColorName ?? "") < ($1.predefinedColorName ?? "") })

    static let color01 = SolidColorBackground(color: .homePageBackground01Dark, colorScheme: .dark, predefinedColorName: "color01")
    static let color02 = SolidColorBackground(color: .homePageBackground02Dark, colorScheme: .dark, predefinedColorName: "color02")
    static let color03 = SolidColorBackground(color: .homePageBackground03Dark, colorScheme: .dark, predefinedColorName: "color03")
    static let color04 = SolidColorBackground(color: .homePageBackground04Dark, colorScheme: .dark, predefinedColorName: "color04")
    static let color05 = SolidColorBackground(color: .homePageBackground05Light, colorScheme: .light, predefinedColorName: "color05")
    static let color06 = SolidColorBackground(color: .homePageBackground06Dark, colorScheme: .dark, predefinedColorName: "color06")
    static let color07 = SolidColorBackground(color: .homePageBackground07Light, colorScheme: .light, predefinedColorName: "color07")
    static let color08 = SolidColorBackground(color: .homePageBackground08Dark, colorScheme: .dark, predefinedColorName: "color08")
    static let color09 = SolidColorBackground(color: .homePageBackground09Light, colorScheme: .light, predefinedColorName: "color09")
    static let color10 = SolidColorBackground(color: .homePageBackground10Light, colorScheme: .light, predefinedColorName: "color10")
    static let color11 = SolidColorBackground(color: .homePageBackground11Light, colorScheme: .light, predefinedColorName: "color11")
    static let color12 = SolidColorBackground(color: .homePageBackground12Light, colorScheme: .light, predefinedColorName: "color12")
    static let color13 = SolidColorBackground(color: .homePageBackground13Dark, colorScheme: .dark, predefinedColorName: "color13")
    static let color14 = SolidColorBackground(color: .homePageBackground14Light, colorScheme: .light, predefinedColorName: "color14")
    static let color15 = SolidColorBackground(color: .homePageBackground15Light, colorScheme: .light, predefinedColorName: "color15")
    static let color16 = SolidColorBackground(color: .homePageBackground16Light, colorScheme: .light, predefinedColorName: "color16")
    static let color17 = SolidColorBackground(color: .homePageBackground17Dark, colorScheme: .dark, predefinedColorName: "color17")
    static let color18 = SolidColorBackground(color: .homePageBackground18Light, colorScheme: .light, predefinedColorName: "color18")
    static let color19 = SolidColorBackground(color: .homePageBackground19Light, colorScheme: .light, predefinedColorName: "color19")
}
