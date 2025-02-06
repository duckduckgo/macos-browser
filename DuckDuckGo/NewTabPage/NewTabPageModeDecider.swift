//
//  NewTabPageModeDecider.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import NewTabPage
import Persistence

enum NewTabPageMode: String {
    case privacyStats, recentActivity
}

protocol NewTabPageModeDeciding {
    var isNewUser: Bool { get }

    var modeOverride: NewTabPageMode? { get set }
}

extension NewTabPageModeDeciding {
    var effectiveMode: NewTabPageMode {
        guard let modeOverride else {
            return isNewUser ? .privacyStats : .recentActivity
        }
        return modeOverride
    }
}

extension Notification.Name {
    static var newTabPageModeDidChange = Notification.Name(rawValue: "newTabPageModeDidChange")
}

final class NewTabPageModeDecider: NewTabPageModeDeciding, NewTabPageSectionsAvailabilityProviding {

    var isPrivacyStatsAvailable: Bool {
        effectiveMode == .privacyStats
    }

    var isRecentActivityAvailable: Bool {
        effectiveMode == .recentActivity
    }

    enum Keys {
        static let isNewUser = "new-tab-page.is-new-user"
        static let modeOverride = "new-tab-page.mode-override"
    }

    var isNewUser: Bool {
        keyValueStore.object(forKey: Keys.isNewUser) as? Bool ?? false
    }

    var modeOverride: NewTabPageMode? {
        get {
            guard let rawValue = keyValueStore.object(forKey: Keys.modeOverride) as? String else {
                return nil
            }
            return NewTabPageMode(rawValue: rawValue)
        }
        set {
            keyValueStore.set(newValue?.rawValue, forKey: Keys.modeOverride)
            NotificationCenter.default.post(name: .newTabPageModeDidChange, object: nil)
        }
    }

    let keyValueStore: KeyValueStoring

    init(keyValueStore: KeyValueStoring = UserDefaults.standard) {
        self.keyValueStore = keyValueStore
        initializeStorageIfNeeded()
    }

    private func initializeStorageIfNeeded() {
        guard keyValueStore.object(forKey: Keys.isNewUser) == nil else {
            return
        }
        let onboardingFinishedKey = UserDefaultsWrapper<Bool>.Key.onboardingFinished.rawValue
        let isOnboardingFinished = (keyValueStore.object(forKey: onboardingFinishedKey) as? Bool) ?? false
        let isNewUser = !isOnboardingFinished
        keyValueStore.set(isNewUser, forKey: Keys.isNewUser)
    }
}
