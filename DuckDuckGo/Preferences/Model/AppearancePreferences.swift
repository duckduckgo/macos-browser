//
//  AppearancePreferences.swift
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

import Foundation

protocol AppearancePreferencesPersistor {
    var showFullURL: Bool { get set }
    var showAutocompleteSuggestions: Bool { get set }
    var currentThemeName: String { get set }
}

struct AppearancePreferencesUserDefaultsPersistor: AppearancePreferencesPersistor {
    @UserDefaultsWrapper(key: .showFullURL, defaultValue: false)
    var showFullURL: Bool

    @UserDefaultsWrapper(key: .showAutocompleteSuggestions, defaultValue: true)
    var showAutocompleteSuggestions: Bool

    @UserDefaultsWrapper(key: .currentThemeName, defaultValue: ThemeName.systemDefault.rawValue)
    var currentThemeName: String
}

enum ThemeName: String, Equatable, CaseIterable {
    case light
    case dark
    case systemDefault

    var appearance: NSAppearance? {
        switch self {
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .systemDefault:
            return "System"
        }
    }

    var imageName: String {
        switch self {
        case .light:
            return "LightModePreview"
        case .dark:
            return "DarkModePreview"
        case .systemDefault:
            return "SystemDefaultPreview"
        }
    }
}

final class AppearancePreferences: ObservableObject {

    static let shared = AppearancePreferences()

    @Published var currentThemeName: ThemeName {
        didSet {
            persistor.currentThemeName = currentThemeName.rawValue
            updateUserInterfaceStyle()
        }
    }

    @Published var showFullURL: Bool {
        didSet {
            persistor.showFullURL = showFullURL
        }
    }

    @Published var showAutocompleteSuggestions: Bool {
        didSet {
            persistor.showAutocompleteSuggestions = showAutocompleteSuggestions
        }
    }

    func updateUserInterfaceStyle() {
        NSApp.appearance = currentThemeName.appearance
    }

    init(persistor: AppearancePreferencesPersistor = AppearancePreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        currentThemeName = .init(rawValue: persistor.currentThemeName) ?? .systemDefault
        showFullURL = persistor.showFullURL
        showAutocompleteSuggestions = persistor.showAutocompleteSuggestions
    }

    private var persistor: AppearancePreferencesPersistor
}
