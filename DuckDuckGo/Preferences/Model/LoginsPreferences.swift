//
//  LoginsPreferences.swift
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

struct LoginsPreferences {

    private enum Keys {
        static let autoLockLoginsThreshold = "preferences.logins.auto-lock-threshold"
    }

    enum AutoLockThreshold: String, CaseIterable {
        case fiveSeconds
        case oneMinute
        case fiveMinutes
        case fifteenMinutes
        case thirtyMinutes
        case oneHour

        var title: String {
            switch self {
            case .fiveSeconds:
                return "5 seconds"
            case .oneMinute:
                return "1 minute"
            case .fiveMinutes:
                return "5 minutes"
            case .fifteenMinutes:
                return "15 minutes"
            case .thirtyMinutes:
                return "30 minutes"
            case .oneHour:
                return "1 hour"
            }
        }
        
        var seconds: TimeInterval {
            switch self {
            case .fiveSeconds:
                return 5
            case .oneMinute:
                return 60
            case .fiveMinutes:
                return 60 * 5
            case .fifteenMinutes:
                return 60 * 15
            case .thirtyMinutes:
                return 60 * 30
            case .oneHour:
                return 60 * 60
            }
        }
    }
    
    // TODO: Put this into secure storage, so that someone can't edit user defaults to remove auto-lock.
    @UserDefaultsWrapper(key: .autoLockLoginsEnabled, defaultValue: true)
    public var shouldAutoLockLogins: Bool
    
    var autoLockThreshold: AutoLockThreshold {
        get {
            if let thresholdName = userDefaults.string(forKey: Keys.autoLockLoginsThreshold),
               let threshold = AutoLockThreshold(rawValue: thresholdName) {
                return threshold
            } else {
                return .fifteenMinutes
            }
        }

        set {
            userDefaults.setValue(newValue.rawValue, forKey: Keys.autoLockLoginsThreshold)
        }
    }
    
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

}

extension LoginsPreferences: PreferenceSection {
    
    var displayName: String {
        return "Logins+"
    }

    var preferenceIcon: NSImage {
        return NSImage(named: "Logins+")!
    }

}
