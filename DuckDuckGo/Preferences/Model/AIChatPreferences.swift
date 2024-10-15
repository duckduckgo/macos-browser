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

protocol AIChatPreferencesPersistor {
    var showShortcutInToolbar: Bool { get set }
    var showShortcutInApplicationMenu: Bool { get set }
}

struct AIChatUserDefaultPreferencesPersistor: AIChatPreferencesPersistor {

    @UserDefaultsWrapper(key: .showAIChatShortcutInToolbar, defaultValue: false)
    var showShortcutInToolbar: Bool

    @UserDefaultsWrapper(key: .showAIChatShortcutInApplicationsMenu, defaultValue: false)
    var showShortcutInApplicationMenu: Bool
}

final class AIChatPreferences: ObservableObject {
    static let shared = AIChatPreferences()
    private var persistor: AIChatPreferencesPersistor

    init(persistor: AIChatPreferencesPersistor = AIChatUserDefaultPreferencesPersistor()) {
        self.persistor = persistor
        showShortcutInToolbar = persistor.showShortcutInToolbar
        showShortcutInApplicationMenu = persistor.showShortcutInApplicationMenu
    }

    @Published var showShortcutInToolbar: Bool {
        didSet {
            persistor.showShortcutInToolbar = showShortcutInToolbar
            if showShortcutInToolbar {
                // pixel A
            } else {
                // pixel B
            }
        }
    }

    @Published var showShortcutInApplicationMenu: Bool {
        didSet {
            persistor.showShortcutInApplicationMenu = showShortcutInApplicationMenu
            if showShortcutInApplicationMenu {
                // pixel A
            } else {
                // pixel B
            }
        }
    }

    @MainActor func openLearnMoreLink() {
        //WindowControllersManager.shared.show(url: url, source: .ui, newTab: true)
    }
}
