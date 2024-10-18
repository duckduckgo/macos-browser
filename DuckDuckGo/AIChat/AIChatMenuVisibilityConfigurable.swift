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

import Combine

protocol AIChatMenuVisibilityConfigurable {
    var shouldDisplayApplicationMenuShortcut: Bool { get }
    var shouldDisplayToolbarShortcut: Bool { get }

    var isFeatureEnabledForApplicationMenuShortcut: Bool { get }
    var isFeatureEnabledForToolbarShortcut: Bool { get }

    var shortcutURL: URL { get }
    var valuesChangedPublisher: PassthroughSubject<Void, Never> { get }
}

final class AIChatMenuConfiguration: AIChatMenuVisibilityConfigurable {
    enum ShortcutType {
        case applicationMenu
        case toolbar
    }

    private var cancellables = Set<AnyCancellable>()
    private var storage: AIChatPreferencesStorage

    var valuesChangedPublisher = PassthroughSubject<Void, Never>()

    var isFeatureEnabledForApplicationMenuShortcut: Bool {
        isFeatureEnabledFor(shortcutType: .applicationMenu)
    }

    var isFeatureEnabledForToolbarShortcut: Bool {
        isFeatureEnabledFor(shortcutType: .toolbar)
    }

    var shouldDisplayToolbarShortcut: Bool {
        return isFeatureEnabledForToolbarShortcut && storage.shouldDisplayToolbarShortcut
    }

    var shouldDisplayApplicationMenuShortcut: Bool {
        return isFeatureEnabledForApplicationMenuShortcut && storage.showShortcutInApplicationMenu
    }

    var shortcutURL: URL {
        URL(string: "https://duckduckgo.com/?q=DuckDuckGo+AI+Chat&ia=chat&duckai=2")!
    }

    init(storage: AIChatPreferencesStorage = DefaultAIChatPreferencesStorage()) {
        self.storage = storage
        self.subscribeToValuesChanged()
    }

    private func subscribeToValuesChanged() {
        storage.shouldDisplayToolbarShortcutPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.valuesChangedPublisher.send()
            }.store(in: &cancellables)

        storage.showShortcutInApplicationMenuPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.valuesChangedPublisher.send()
            }.store(in: &cancellables)
    }

    private func isFeatureEnabledFor(shortcutType: ShortcutType) -> Bool {
        switch shortcutType {
        case .applicationMenu:
            // Use privacy config here
            return true
        case .toolbar:
            // Use privacy config here
            return true
        }
    }
}
