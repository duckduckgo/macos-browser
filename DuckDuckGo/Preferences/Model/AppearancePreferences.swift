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
    var defaultPageZoom: CGFloat { get set }
}

struct AppearancePreferencesUserDefaultsPersistor: AppearancePreferencesPersistor {
    @UserDefaultsWrapper(key: .showFullURL, defaultValue: false)
    var showFullURL: Bool

    @UserDefaultsWrapper(key: .showAutocompleteSuggestions, defaultValue: true)
    var showAutocompleteSuggestions: Bool

    @UserDefaultsWrapper(key: .currentThemeName, defaultValue: ThemeName.systemDefault.rawValue)
    var currentThemeName: String

    @UserDefaultsWrapper(key: .defaultPageZoom, defaultValue: DefaultZoomValue.percent100.rawValue)
    var defaultPageZoom: CGFloat
}

enum DefaultZoomValue: CGFloat, CaseIterable {
    case percent50 = 0.5
    case percent75 = 0.75
    case percent85 = 0.85
    case percent100 = 1.0
    case percent115 = 1.15
    case percent125 = 1.25
    case percent150 = 1.50
    case percent175 = 1.75
    case percent200 = 2.0
    case percent250 = 2.5
    case percent300 = 3.0

    var displayString: String {
        let percentage = (self.rawValue * 100).rounded()
        return String(format: "%.0f%%", percentage)
    }

    var index: Int {DefaultZoomValue.allCases.firstIndex(of: self) ?? 3}
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

    @Published var defaultPageZoom: DefaultZoomValue {
        didSet {
            persistor.defaultPageZoom = defaultPageZoom.rawValue
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
        defaultPageZoom =  .init(rawValue: persistor.defaultPageZoom) ?? .percent100
    }

    private var persistor: AppearancePreferencesPersistor
}
