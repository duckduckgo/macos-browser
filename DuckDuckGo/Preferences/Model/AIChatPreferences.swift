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

    private let pinningManager: PinningManager
    private var preferencesStorage: AIChatPreferencesStorage
    private let learnMoreURL = URL(string: "https://duckduckgo.com/duckduckgo-help-pages/aichat/")!
    private var cancellables = Set<AnyCancellable>()

    init(storage: AIChatPreferencesStorage = AIChatPreferencesUserDefaultsStorage(),
         pinningManager: PinningManager = LocalPinningManager.shared) {
        self.preferencesStorage = storage
        self.showShortcutInApplicationMenu = storage.showShortcutInApplicationMenu
        self.pinningManager = pinningManager
        self.showShortcutInToolbar = pinningManager.isPinned(.aiChat)
        subscribeToShowInBrowserToolbarSettingsChanges()
    }

    @Published var showShortcutInToolbar: Bool {
        didSet {
            if showShortcutInToolbar {
                pinningManager.pin(.aiChat)
            } else {
                pinningManager.unpin(.aiChat)
            }
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

    private func subscribeToShowInBrowserToolbarSettingsChanges() {
        NotificationCenter.default.publisher(for: .PinnedViewsChanged).sink { [weak self] notification in
            guard let self = self else {
                return
            }

            if let userInfo = notification.userInfo as? [String: Any],
               let viewType = userInfo[LocalPinningManager.pinnedViewChangedNotificationViewTypeKey] as? String,
               let view = PinnableView(rawValue: viewType) {
                switch view {
                case .aiChat: self.showShortcutInToolbar = self.pinningManager.isPinned(.aiChat)
                default: break
                }
            }
        }
        .store(in: &cancellables)
    }
}

protocol AIChatPreferencesStorage {
    var showShortcutInApplicationMenu: Bool { get set }
}

struct AIChatPreferencesUserDefaultsStorage: AIChatPreferencesStorage {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var showShortcutInApplicationMenu: Bool {
        get { userDefaults.showAIChatShortcutInApplicationMenu }
        set { userDefaults.showAIChatShortcutInApplicationMenu = newValue }
    }
}

private extension UserDefaults {
    enum Keys {
        static let showAIChatShortcutInApplicationMenu = "aichat.showAIChatShortcutInApplicationMenu"
    }

    var showAIChatShortcutInApplicationMenu: Bool {
        get { bool(forKey: Keys.showAIChatShortcutInApplicationMenu) }
        set { set(newValue, forKey: Keys.showAIChatShortcutInApplicationMenu) }
    }
}
