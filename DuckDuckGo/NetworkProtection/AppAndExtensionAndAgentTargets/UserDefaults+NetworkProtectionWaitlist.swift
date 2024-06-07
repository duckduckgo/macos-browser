//
//  UserDefaults+NetworkProtectionWaitlist.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

enum WaitlistOverride: Int {
    case useRemoteValue = 0
    case on
    case off

    static let `default`: WaitlistOverride = .useRemoteValue
}

protocol WaitlistBetaOverriding {
    var waitlistActive: WaitlistOverride { get }
    var waitlistEnabled: WaitlistOverride { get }
}

final class DefaultWaitlistBetaOverrides: WaitlistBetaOverriding {
    private let userDefaults: UserDefaults = .netP

    var waitlistActive: WaitlistOverride {
        .init(rawValue: userDefaults.networkProtectionWaitlistBetaActiveOverrideRawValue) ?? .default
    }

    var waitlistEnabled: WaitlistOverride {
        .init(rawValue: userDefaults.networkProtectionWaitlistEnabledOverrideRawValue) ?? .default
    }
}

extension UserDefaults {
    // Convenience declaration
    var networkProtectionWaitlistActiveOverrideRawValueKey: String {
        UserDefaultsWrapper<Any>.Key.networkProtectionWaitlistActiveOverrideRawValue.rawValue
    }

    /// For KVO to work across processes (Menu App + Main App) we need to declare this dynamic var in a `UserDefaults`
    /// extension, and the key for this property must match its name exactly.
    ///
    @objc
    dynamic var networkProtectionWaitlistBetaActiveOverrideRawValue: Int {
        get {
            value(forKey: networkProtectionWaitlistActiveOverrideRawValueKey) as? Int ?? WaitlistOverride.default.rawValue
        }

        set {
            set(newValue, forKey: networkProtectionWaitlistActiveOverrideRawValueKey)
        }
    }

    // Convenience declaration
    var networkProtectionWaitlistEnabledOverrideRawValueKey: String {
        UserDefaultsWrapper<Any>.Key.networkProtectionWaitlistEnabledOverrideRawValue.rawValue
    }

    /// For KVO to work across processes (Menu App + Main App) we need to declare this dynamic var in a `UserDefaults`
    /// extension, and the key for this property must match its name exactly.
    ///
    @objc
    dynamic var networkProtectionWaitlistEnabledOverrideRawValue: Int {
        get {
            value(forKey: networkProtectionWaitlistEnabledOverrideRawValueKey) as? Int ?? WaitlistOverride.default.rawValue
        }

        set {
            set(newValue, forKey: networkProtectionWaitlistEnabledOverrideRawValueKey)
        }
    }
}
