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
    var shortcutURL: URL { get }
    var valuesChangedPublisher: PassthroughSubject<Void, Never> { get }
}

final class AIChatMenuConfiguration: AIChatMenuVisibilityConfigurable {
    var valuesChangedPublisher = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let preferences: AIChatPreferences

    enum ShortcutType {
        case applicationMenu
        case toolbar
    }

    // MARK: - Public

    var shouldDisplayApplicationMenuShortcut: Bool {
        return isFeatureEnabledFor(shortcutType: .applicationMenu) && preferences.showShortcutInApplicationMenu
    }

    var shouldDisplayToolbarShortcut: Bool {
        return isFeatureEnabledFor(shortcutType: .toolbar) && preferences.showShortcutInToolbar
    }

    var shortcutURL: URL {
        URL(string: "https://duckduckgo.com/?q=DuckDuckGo+AI+Chat&ia=chat&duckai=2")!
    }

    init(preferences: AIChatPreferences = .shared) {
        self.preferences = preferences
        subscribeToValueChanges()
    }

    // MARK: - Private

    private func subscribeToValueChanges() {
        preferences.$showShortcutInToolbar
            .merge(with: preferences.$showShortcutInApplicationMenu)
            .dropFirst()
            .sink { [weak self] _ in
                self?.valuesChangedPublisher.send(())
            }
            .store(in: &cancellables)
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
