//
//  AIChatPreferencesStorage.swift
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

protocol AIChatPreferencesStorage {
    var showShortcutInApplicationMenu: Bool { get set }
    var shouldDisplayToolbarShortcut: Bool { get set }

    var showShortcutInApplicationMenuPublisher: AnyPublisher<Bool, Never> { get }
    var shouldDisplayToolbarShortcutPublisher: AnyPublisher<Bool, Never> { get }
}

struct DefaultAIChatPreferencesStorage: AIChatPreferencesStorage {
    var showShortcutInApplicationMenuPublisher: AnyPublisher<Bool, Never> {
        userDefaults.showAIChatShortcutInApplicationMenuPublisher
    }

    var shouldDisplayToolbarShortcutPublisher: AnyPublisher<Bool, Never> {
        NotificationCenter.default.publisher(for: .PinnedViewsChanged)
            .compactMap { notification -> PinnableView? in
                guard let userInfo = notification.userInfo as? [String: Any],
                      let viewType = userInfo[LocalPinningManager.pinnedViewChangedNotificationViewTypeKey] as? String,
                      let view = PinnableView(rawValue: viewType) else {
                    return nil
                }
                return view == .aiChat ? view : nil
            }
            .flatMap { view -> AnyPublisher<Bool, Never> in
                return Just(self.pinningManager.isPinned(view)).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private let userDefaults: UserDefaults
    private let pinningManager: PinningManager

    init(userDefaults: UserDefaults = .standard,
         pinningManager: PinningManager = LocalPinningManager.shared) {
        self.userDefaults = userDefaults
        self.pinningManager = pinningManager
    }

    var shouldDisplayToolbarShortcut: Bool {
        get { pinningManager.isPinned(.aiChat) }
        set {
            if newValue {
                pinningManager.pin(.aiChat)
            } else {
                pinningManager.unpin(.aiChat)
            }
        }
    }

    var showShortcutInApplicationMenu: Bool {
        get { userDefaults.showAIChatShortcutInApplicationMenu }
        set { userDefaults.showAIChatShortcutInApplicationMenu = newValue }
    }
}

private extension UserDefaults {
    private var showAIChatShortcutInApplicationMenuKey: String {
        "aichat.showAIChatShortcutInApplicationMenu"
    }

    static let showAIChatShortcutInApplicationMenuDefaultValue = false

    @objc
    dynamic var showAIChatShortcutInApplicationMenu: Bool {
        get {
            value(forKey: showAIChatShortcutInApplicationMenuKey) as? Bool ?? Self.showAIChatShortcutInApplicationMenuDefaultValue
        }

        set {
            guard newValue != showAIChatShortcutInApplicationMenu else {
                return
            }

            set(newValue, forKey: showAIChatShortcutInApplicationMenuKey)
        }
    }

    var showAIChatShortcutInApplicationMenuPublisher: AnyPublisher<Bool, Never> {
        publisher(for: \.showAIChatShortcutInApplicationMenu).eraseToAnyPublisher()
    }
}
