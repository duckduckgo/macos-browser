//
//  AIChatMenuVisibilityConfigurable.swift
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

protocol AIChatMenuVisibilityConfigurable {
    var shouldDisplayApplicationMenuShortcut: Bool { get }
    var shouldDisplayToolbarShortcut: Bool { get }
    var shortcutURL: URL { get }
}

struct AIChatMenuConfiguration: AIChatMenuVisibilityConfigurable {
    enum ShortcutType {
        case applicationMenu
        case toolbar
    }

    private let preferencesPersistor: AIChatPreferencesPersistor

    var shouldDisplayApplicationMenuShortcut: Bool {
        return isFeatureEnabledFor(shortcutType: .applicationMenu) && preferencesPersistor.showShortcutInApplicationMenu
    }

    var shouldDisplayToolbarShortcut: Bool {
        return isFeatureEnabledFor(shortcutType: .toolbar) && preferencesPersistor.showShortcutInToolbar
    }

    var shortcutURL: URL {
        URL(string: "https://duckduckgo.com/?q=DuckDuckGo+AI+Chat&ia=chat&duckai=2")!
    }

    init(preferencesPersistor: AIChatPreferencesPersistor = AIChatUserDefaultPreferencesPersistor()) {
        self.preferencesPersistor = preferencesPersistor
    }

    private func isFeatureEnabledFor(shortcutType: ShortcutType) -> Bool {
        switch shortcutType {
        case .applicationMenu:
            return true
        case .toolbar:
            return true
        }
    }
}
