//
//  AIChatPreferences.swift
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

import Combine
import Foundation

final class AIChatPreferences: ObservableObject {
    static let shared = AIChatPreferences()

    private var preferencesStorage: AIChatPreferencesStorage
    private let learnMoreURL = URL(string: "https://duckduckgo.com/duckduckgo-help-pages/aichat/")!

    init(storage: AIChatPreferencesStorage = AIChatPreferencesUserDefaultsStorage()) {
        self.preferencesStorage = storage
        self.showShortcutInToolbar = storage.showShortcutInToolbar
        self.showShortcutInApplicationMenu = storage.showShortcutInApplicationMenu
    }

    @Published var showShortcutInToolbar: Bool {
        didSet {
            preferencesStorage.showShortcutInToolbar = showShortcutInToolbar
        }
    }

    @Published var showShortcutInApplicationMenu: Bool {
        didSet {
            preferencesStorage.showShortcutInApplicationMenu = showShortcutInApplicationMenu
        }
    }

    @MainActor func openLearnMoreLink() {
        WindowControllersManager.shared.show(url: learnMoreURL, source: .ui, newTab: true)
    }
}

protocol AIChatPreferencesStorage {
    var showShortcutInToolbar: Bool { get set }
    var showShortcutInApplicationMenu: Bool { get set }
}

struct AIChatPreferencesUserDefaultsStorage: AIChatPreferencesStorage {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var showShortcutInToolbar: Bool {
        get { userDefaults.showAIChatShortcutInToolbar }
        set { userDefaults.showAIChatShortcutInToolbar = newValue }
    }

    var showShortcutInApplicationMenu: Bool {
        get { userDefaults.showAIChatShortcutInApplicationMenu }
        set { userDefaults.showAIChatShortcutInApplicationMenu = newValue }
    }
}

private extension UserDefaults {
    enum Keys {
        static let showAIChatShortcutInToolbar = "aichat.showAIChatShortcutInToolbar"
        static let showAIChatShortcutInApplicationMenu = "aichat.showAIChatShortcutInApplicationMenu"
    }

    var showAIChatShortcutInApplicationMenu: Bool {
        get { bool(forKey: Keys.showAIChatShortcutInApplicationMenu) }
        set { set(newValue, forKey: Keys.showAIChatShortcutInApplicationMenu) }
    }

    var showAIChatShortcutInToolbar: Bool {
        get { bool(forKey: Keys.showAIChatShortcutInToolbar) }
        set { set(newValue, forKey: Keys.showAIChatShortcutInToolbar) }
    }
}
