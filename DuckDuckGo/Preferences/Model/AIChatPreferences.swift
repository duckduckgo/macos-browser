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
import BrowserServicesKit

final class AIChatPreferences: ObservableObject {
    static let shared = AIChatPreferences()
    private var storage: AIChatPreferencesStorage
    private var cancellables = Set<AnyCancellable>()
    private let configuration: AIChatMenuVisibilityConfigurable
    private let learnMoreURL = URL(string: "https://duckduckgo.com/duckduckgo-help-pages/aichat/")!

    init(storage: AIChatPreferencesStorage = DefaultAIChatPreferencesStorage(),
         configuration: AIChatMenuVisibilityConfigurable = AIChatMenuConfiguration()) {
        self.storage = storage
        self.configuration = configuration

        showShortcutInToolbar = storage.shouldDisplayToolbarShortcut
        showShortcutInApplicationMenu = storage.showShortcutInApplicationMenu

        subscribeToShowInToolbarSettingsChanges()
        subscribeToShowInApplicationMenuSettingsChanges()
    }

    func subscribeToShowInToolbarSettingsChanges() {
        storage.shouldDisplayToolbarShortcutPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.showShortcutInToolbar, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    func subscribeToShowInApplicationMenuSettingsChanges() {
        storage.showShortcutInApplicationMenuPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.showShortcutInApplicationMenu, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    var shouldShowToolBarShortcutOption: Bool {
        self.configuration.isFeatureEnabledForToolbarShortcut
    }

    var shouldShowApplicationMenuShortcutOption: Bool {
        self.configuration.isFeatureEnabledForApplicationMenuShortcut
    }

    @Published var showShortcutInToolbar: Bool {
        didSet {
            storage.shouldDisplayToolbarShortcut = showShortcutInToolbar
        }
    }

    @Published var showShortcutInApplicationMenu: Bool {
        didSet {
            storage.showShortcutInApplicationMenu = showShortcutInApplicationMenu
        }
    }

    @MainActor func openLearnMoreLink() {
        WindowControllersManager.shared.show(url: learnMoreURL, source: .ui, newTab: true)
    }

    @MainActor func openAIChatLink() {
        AIChatTabOpener.openAIChatTab()
    }
}
