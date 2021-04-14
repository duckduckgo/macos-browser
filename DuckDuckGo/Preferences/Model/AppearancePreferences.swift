//
//  AppearancePreferences.swift
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

enum ThemeName: String {
    case systemDefault
    case light
    case dark
}

struct AppearancePreferences {

    private struct Keys {
        static let currentThemeNameKey = "com.duckduckgo.macos.currentThemeNameKey"
    }

    var currentThemeName: ThemeName {

        get {
            var currentThemeName: ThemeName?

            if let stringName = userDefaults.string(forKey: Keys.currentThemeNameKey) {
                currentThemeName = ThemeName(rawValue: stringName)
            }

            return currentThemeName ?? .systemDefault
        }

        set {
            userDefaults.setValue(newValue.rawValue, forKey: Keys.currentThemeNameKey)
            updateUserInterfaceStyle()
        }

    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func updateUserInterfaceStyle(windows: [NSWindow] = WindowsManager.windows) {
        switch currentThemeName {
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        default:
            NSApp.appearance = nil
        }
    }

}

extension AppearancePreferences: PreferenceSection {

    var displayName: String {
        return "Appearance"
    }

    var preferenceIcon: NSImage {
        return NSImage(named: "Appearance")!
    }

}
