//
//  AutofillPreferences.swift
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

protocol AutofillPreferencesPersistor {
    var isAutoLockEnabled: Bool { get set }
    var autoLockThreshold: AutofillAutoLockThreshold { get set }
    var askToSaveUsernamesAndPasswords: Bool { get set }
    var askToSaveAddresses: Bool { get set }
    var askToSavePaymentMethods: Bool { get set }
    var passwordManager: PasswordManager { get set }
}

enum PasswordManager: String, CaseIterable {
    case duckduckgo
    case bitwarden
}

enum AutofillAutoLockThreshold: String, CaseIterable {
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    var title: String {
        switch self {
        case .oneMinute: return UserText.autoLockThreshold1Minute
        case .fiveMinutes: return UserText.autoLockThreshold5Minutes
        case .fifteenMinutes: return UserText.autoLockThreshold15Minutes
        case .thirtyMinutes: return UserText.autoLockThreshold30Minutes
        case .oneHour: return UserText.autoLockThreshold1Hour
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .oneMinute: return 60
        case .fiveMinutes: return 60 * 5
        case .fifteenMinutes: return 60 * 15
        case .thirtyMinutes: return 60 * 30
        case .oneHour: return 60 * 60
        }
    }
}

extension NSNotification.Name {
    static let autofillAutoLockSettingsDidChange = NSNotification.Name("autofillAutoLockSettingsDidChange")
}

final class AutofillPreferences: AutofillPreferencesPersistor {

    public var isAutoLockEnabled: Bool {
        get {
            return statisticsStore.autoLockEnabled
        }

        set {
            let oldValue = statisticsStore.autoLockEnabled
            statisticsStore.autoLockEnabled = newValue

            if oldValue != newValue {
                NotificationCenter.default.post(name: .autofillAutoLockSettingsDidChange, object: nil)
            }
        }
    }

    var autoLockThreshold: AutofillAutoLockThreshold {
        get {
            if let rawValue = statisticsStore.autoLockThreshold, let threshold = AutofillAutoLockThreshold(rawValue: rawValue) {
                return threshold
            } else {
                return .fifteenMinutes
            }
        }

        set {
            statisticsStore.autoLockThreshold = newValue.rawValue
        }
    }

    @UserDefaultsWrapper(key: .askToSaveUsernamesAndPasswords, defaultValue: true)
    var askToSaveUsernamesAndPasswords: Bool

    @UserDefaultsWrapper(key: .askToSaveAddresses, defaultValue: true)
    var askToSaveAddresses: Bool

    @UserDefaultsWrapper(key: .askToSavePaymentMethods, defaultValue: true)
    var askToSavePaymentMethods: Bool

    var passwordManager: PasswordManager {
        get {
            return PasswordManager(rawValue: selectedPasswordManager) ?? .duckduckgo
        }

        set {
            selectedPasswordManager = newValue.rawValue
        }
    }

    @UserDefaultsWrapper(key: .selectedPasswordManager, defaultValue: PasswordManager.duckduckgo.rawValue)
    private var selectedPasswordManager: String

    private var statisticsStore: StatisticsStore {
        return injectedDependencyStore ?? defaultDependencyStore
    }

    private let injectedDependencyStore: StatisticsStore?
    private lazy var defaultDependencyStore: StatisticsStore = {
        return LocalStatisticsStore()
    }()

    init(statisticsStore: StatisticsStore? = nil) {
        self.injectedDependencyStore = statisticsStore
    }

}
