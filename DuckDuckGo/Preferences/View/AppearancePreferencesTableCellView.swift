//
//  AppearancePreferencesTableCellView.swift
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

import Foundation

final class AppearancePreferencesTableCellView: NSTableCellView {

    private enum Constants {
        static let appearanceButtonCornerRadius: CGFloat = 7
        static let appearanceButtonBorderWidth: CGFloat = 2
    }

    static let identifier = NSUserInterfaceItemIdentifier("AppearancePreferencesTableCellView")

    static func nib() -> NSNib {
        return NSNib(nibNamed: "AppearancePreferencesTableCellView", bundle: Bundle.main)!
    }

    @IBOutlet var lightModeAppearanceButton: PaddedImageButton!
    @IBOutlet var darkModeAppearanceButton: PaddedImageButton!
    @IBOutlet var systemDefaultAppearanceButton: PaddedImageButton!

    private var appearancePreferences = AppearancePreferences()
    private var buttons: [NSButton] {
        [lightModeAppearanceButton, darkModeAppearanceButton, systemDefaultAppearanceButton]
    }

    @IBAction func selectedTheme(_ sender: NSButton) {
        switch sender {
        case lightModeAppearanceButton:
            appearancePreferences.currentThemeName = .light
            update(with: .light)
        case darkModeAppearanceButton:
            appearancePreferences.currentThemeName = .dark
            update(with: .dark)
        case systemDefaultAppearanceButton:
            appearancePreferences.currentThemeName = .systemDefault
            update(with: .systemDefault)
        default:
            assertionFailure("\(#file): Selected theme with an unknown sender")
        }
    }

    func update(with appearance: ThemeName) {
        buttons.forEach(resetButtonStyle(for:))

        switch appearance {
        case .dark:
            applyBorderedStyle(to: darkModeAppearanceButton)
        case .light:
            applyBorderedStyle(to: lightModeAppearanceButton)
        case .systemDefault:
            applyBorderedStyle(to: systemDefaultAppearanceButton)
        }
    }

    func applyBorderedStyle(to button: NSButton) {
        button.wantsLayer = true
        button.layer?.cornerRadius = Constants.appearanceButtonCornerRadius
        button.layer?.borderWidth = Constants.appearanceButtonBorderWidth
        button.layer?.borderColor = NSColor.controlAccentColor.cgColor
    }

    func resetButtonStyle(for button: NSButton) {
        button.layer?.cornerRadius = 0
        button.layer?.borderWidth = 0
        button.layer?.borderColor = nil
    }
}
