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

    static var homePageBackgroundColor: NSColor {
        NSColor(named: "HomePageBackgroundColor")!
    }

    static var homePageSearchBarBackgroundColor: NSColor {
         return NSColor(named: "HomePageSearchBarBackgroundColor")!
     }

    static var addressBarFocusedBackgroundColor: NSColor {
        NSColor(named: "AddressBarFocusedBackgroundColor")!
    }

    static var addressBarBackgroundColor: NSColor {
        NSColor(named: "AddressBarBackgroundColor")!
    }

    static var addressBarBorderColor: NSColor {
        NSColor(named: "AddressBarBorderColor")!
    }

    static var addressBarShadowColor: NSColor {
        NSColor(named: "AddressBarShadowColor")!
    }

    static var addressBarSolidSeparatorColor: NSColor {
        NSColor(named: "AddressBarSolidSeparatorColor")!
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

    static var inactiveSearchBarBackground: NSColor {
        NSColor(named: "InactiveSearchBarBackground")!
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

    static var buttonMouseOverColor: NSColor {
        NSColor(named: "ButtonMouseOverColor")!
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

    static var dialogPanelBackgroundColor: NSColor {
        NSColor(named: "DialogPanelBackground")!
    }

    static let bookmarkFilledTint = NSColor(named: "BookmarkFilledTint")!

    static let bookmarkRepresentingColor1 = NSColor(named: "BookmarkRepresentingColor1")!
    static let bookmarkRepresentingColor2 = NSColor(named: "BookmarkRepresentingColor2")!
    static let bookmarkRepresentingColor3 = NSColor(named: "BookmarkRepresentingColor3")!
    static let bookmarkRepresentingColor4 = NSColor(named: "BookmarkRepresentingColor4")!
    static let bookmarkRepresentingColor5 = NSColor(named: "BookmarkRepresentingColor5")!

    static var buttonMouseDownColor: NSColor {
        NSColor(named: "ButtonMouseDownColor")!
    }

    static let buttonColor: NSColor = NSColor(named: "ButtonColor")!

    static var logoBackground: NSColor {
        NSColor(named: "LogoBackgroundColor")!
    }

}
