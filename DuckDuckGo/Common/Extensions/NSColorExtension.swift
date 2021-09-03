//
//  NSColorExtension.swift
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

extension NSColor {

    convenience init?(hex: String) {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        let hex = hex.drop(prefix: "#")
        let scanner = Scanner(string: hex)
        var hexValue: CUnsignedLongLong = 0
        guard scanner.scanHexInt64(&hexValue) else { return nil }

        switch hex.count {
        case 3:
            red   = CGFloat((hexValue & 0xF00) >> 8)       / 15.0
            green = CGFloat((hexValue & 0x0F0) >> 4)       / 15.0
            blue  = CGFloat(hexValue & 0x00F)              / 15.0
            alpha = 1
        case 4:
            red   = CGFloat((hexValue & 0xF000) >> 12)     / 15.0
            green = CGFloat((hexValue & 0x0F00) >> 8)      / 15.0
            blue  = CGFloat((hexValue & 0x00F0) >> 4)      / 15.0
            alpha = CGFloat(hexValue & 0x000F)             / 15.0
        case 6:
            red   = CGFloat((hexValue & 0xFF0000) >> 16)   / 255.0
            green = CGFloat((hexValue & 0x00FF00) >> 8)    / 255.0
            blue  = CGFloat(hexValue & 0x0000FF)           / 255.0
            alpha = 1
        case 8:
            red   = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            green = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            blue  = CGFloat((hexValue & 0x0000FF00) >> 8)  / 255.0
            alpha = CGFloat(hexValue & 0x000000FF)         / 255.0
        default:
            return nil
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    static var homepageBackgroundColor: NSColor {
        NSColor(named: "HomepageBackgroundColor")!
    }

    static var addressBarFocusedBackgroundColor: NSColor {
        NSColor(named: "AddressBarFocusedBackgroundColor")!
    }
    
    static var addressBarBackgroundColor: NSColor {
        NSColor(named: "AddressBarBackgroundColor")!
    }

    static var addressBarShadowColor: NSColor {
        NSColor(named: "AddressBarShadowColor")!
    }

    static var suggestionsShadowColor: NSColor {
        NSColor(named: "SuggestionsShadowColor")!
    }

    static let detailAccentColor = NSColor(catalogName: "System", colorName: "detailAccentColor") ?? .controlAccentColor

    static var addressBarSuffixColor: NSColor {
        .detailAccentColor
    }

    static var findInPageFocusedBackgroundColor: NSColor {
        NSColor(named: "FindInPageFocusedBackgroundColor")!
    }
    
    static var suggestionTextColor: NSColor {
        NSColor(named: "SuggestionTextColor")!
    }
    
    static var suggestionIconColor: NSColor {
        NSColor(named: "SuggestionIconColor")!
    }

    static var selectedSuggestionTintColor: NSColor {
        NSColor(named: "SelectedSuggestionTintColor")!
    }

    static var interfaceBackgroundColor: NSColor {
        NSColor(named: "InterfaceBackgroundColor")!
    }
    
    static var tabMouseOverColor: NSColor {
        NSColor(named: "TabMouseOverColor")!
    }

    static var tabBarBackgroundColor: NSColor {
        NSColor(named: "WindowBackgroundColor")!
    }

    static var progressBarGradientDarkColor: NSColor {
        .controlAccentColor
    }

    static var progressBarGradientLightColor: NSColor {
        .detailAccentColor
    }

    static var backgroundSecondaryColor: NSColor {
        NSColor(named: "BackgroundSecondaryColor")!
    }

    static var tableCellEditingColor: NSColor {
        NSColor(named: "TableCellEditingColor")!
    }

    static var rowHoverColor: NSColor {
        NSColor(named: "RowHoverColor")!
    }

    static var rowDragDropColor: NSColor {
        NSColor(named: "RowDragDropColor")!
    }

    static var privacyEnabledColor: NSColor {
        NSColor(named: "PrivacyEnabledColor")!
    }

    static var editingPanelColor: NSColor {
        NSColor(named: "EditingPanelColor")!
    }

    static let bookmarkFilledTint = NSColor(named: "BookmarkFilledTint")!

    static let bookmarkRepresentingColor1 = NSColor(named: "BookmarkRepresentingColor1")!
    static let bookmarkRepresentingColor2 = NSColor(named: "BookmarkRepresentingColor2")!
    static let bookmarkRepresentingColor3 = NSColor(named: "BookmarkRepresentingColor3")!
    static let bookmarkRepresentingColor4 = NSColor(named: "BookmarkRepresentingColor4")!
    static let bookmarkRepresentingColor5 = NSColor(named: "BookmarkRepresentingColor5")!

}
