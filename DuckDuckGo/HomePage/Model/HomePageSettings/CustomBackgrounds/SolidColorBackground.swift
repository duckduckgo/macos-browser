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

enum SolidColorBackgroundPickerItem: Hashable, Equatable, Identifiable, CustomBackgroundConvertible {
    var id: Int {
        hashValue
    }

    case picker(SolidColorBackground)
    case background(SolidColorBackground)

    var customBackground: CustomBackground {
        switch self {
        case .picker(let background), .background(let background):
            return background.customBackground
        }
    }
}

struct SolidColorBackground: Hashable, Equatable, Identifiable, LosslessStringConvertible, ColorSchemeProviding, CustomBackgroundConvertible {
    var id: Int {
        color.hashValue
    }

    init(color: NSColor, colorScheme: ColorScheme? = nil) {
        self.color = color
        self.colorScheme = colorScheme ?? (color.brightness > 0.5 ? .light : .dark)
    }

    init?(_ description: String) {
        guard let color = NSColor(hex: description) else {
            return nil
        }
        self.init(color: color)
    }

    var description: String {
        color.hex(includeAlpha: false)
    }

    let color: NSColor
    let colorScheme: ColorScheme

    var customBackground: CustomBackground {
        .solidColor(self)
    }

    static let predefinedColors: [SolidColorBackground] = [
        .lightPink,
        .darkPink,
        .lightOrange,
        .darkOrange,
        .lightYellow,
        .darkYellow,
        .lightGreen,
        .darkGreen,
        .lightBlue,
        .darkBlue,
        .lightPurple,
        .darkPurple,
        .gray,
        .black
    ]

    static let lightPink = SolidColorBackground(color: .homePageBackgroundLightPink, colorScheme: .light)
    static let darkPink = SolidColorBackground(color: .homePageBackgroundDarkPink, colorScheme: .dark)
    static let lightOrange = SolidColorBackground(color: .homePageBackgroundLightOrange, colorScheme: .light)
    static let darkOrange = SolidColorBackground(color: .homePageBackgroundDarkOrange, colorScheme: .dark)
    static let lightYellow = SolidColorBackground(color: .homePageBackgroundLightYellow, colorScheme: .light)
    static let darkYellow = SolidColorBackground(color: .homePageBackgroundDarkYellow, colorScheme: .light)
    static let lightGreen = SolidColorBackground(color: .homePageBackgroundLightGreen, colorScheme: .light)
    static let darkGreen = SolidColorBackground(color: .homePageBackgroundDarkGreen, colorScheme: .dark)
    static let lightBlue = SolidColorBackground(color: .homePageBackgroundLightBlue, colorScheme: .light)
    static let darkBlue = SolidColorBackground(color: .homePageBackgroundDarkBlue, colorScheme: .dark)
    static let lightPurple = SolidColorBackground(color: .homePageBackgroundLightPurple, colorScheme: .light)
    static let darkPurple = SolidColorBackground(color: .homePageBackgroundDarkPurple, colorScheme: .dark)
    static let gray = SolidColorBackground(color: .homePageBackgroundGray, colorScheme: .dark)
    static let black = SolidColorBackground(color: .homePageBackgroundBlack, colorScheme: .dark)
}
