//
//  LocalStatisticsStore.swift
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

final class LocalStatisticsStore: StatisticsStore {

    struct LegacyStatisticsStore {
        @UserDefaultsWrapper(key: .atb, defaultValue: nil)
        var atb: String?

        @UserDefaultsWrapper(key: .installDate, defaultValue: nil)
        var installDate: Date?

        @UserDefaultsWrapper(key: .searchRetentionAtb, defaultValue: nil)
        var searchRetentionAtb: String?

        @UserDefaultsWrapper(key: .appRetentionAtb, defaultValue: nil)
        var appRetentionAtb: String?

        @UserDefaultsWrapper(key: .lastAppRetentionRequestDate, defaultValue: nil)
        var lastAppRetentionRequestDate: Date?

        /// Used to determine whether this clearing process took place. While we no longer use these values, we need to know if a user has upgraded from a
        /// version which did use them, so that they can be shephered into an unlocked waitlist state. When the waitlist feature is removed, this key can be deleted.
        @UserDefaultsWrapper(key: .legacyStatisticsStoreDataCleared, defaultValue: false)
        var legacyStatisticsStoreDataCleared: Bool

        mutating func clear() {
            if atb != nil || installDate != nil {
                legacyStatisticsStoreDataCleared = true
            }

            atb = nil
            installDate = nil
            searchRetentionAtb = nil
            appRetentionAtb = nil
            lastAppRetentionRequestDate = nil
        }
    }

    private struct Keys {
        static let installDate = "stats.installdate.key"
        static let atb = "stats.atb.key"
        static let searchRetentionAtb = "stats.retentionatb.key"
        static let appRetentionAtb = "stats.appretentionatb.key"
        static let variant = "stats.variant.key"
        static let lastAppRetentionRequestDate = "stats.appretentionatb.last.request.key"
        static let waitlistUnlocked = "waitlist.unlocked"
        static let autoLockEnabled = "auto-lock.enabled"
        static let autoLockThreshold = "auto-lock.threshold"
    }

    // These are the original ATB keys that have been replaced in order to resolve retention data issues.
    // These keys should be removed from the database in the future.
    private struct DeprecatedKeys {
        static let installDate = "statistics.installdate.key"
        static let atb = "statistics.atb.key"
        static let searchRetentionAtb = "statistics.retentionatb.key"
        static let appRetentionAtb = "statistics.appretentionatb.key"
        static let variant = "statistics.variant.key"
        static let lastAppRetentionRequestDate = "statistics.appretentionatb.last.request.key"
    }

    private let pixelDataStore: PixelDataStore

    init(pixelDataStore: PixelDataStore = LocalPixelDataStore.shared) {
        self.pixelDataStore = pixelDataStore

        var legacyStatisticsStore = LegacyStatisticsStore()
        legacyStatisticsStore.clear()
    }

    var hasInstallStatistics: Bool {
        return atb != nil
    }

    /// There are three cases in which users can upgrade to a version which includes the Lock Screen feature:
    ///
    /// 1. Users with ATB stored in User Defaults
    /// 2. Users with ATB stored under the DeprecatedKeys values
    /// 3. Users with ATB stored under the Keys values
    ///
    /// This property checks each of these cases to determine whether a user has upgraded from an existing install in any of these cases.
    var hasCurrentOrDeprecatedInstallStatistics: Bool {
        let legacyATBWasMigrated = LegacyStatisticsStore().legacyStatisticsStoreDataCleared
        let deprecatedATB: String? = pixelDataStore.value(forKey: DeprecatedKeys.atb)
        let hasDeprecatedATB = deprecatedATB != nil

        return hasInstallStatistics || hasDeprecatedATB || legacyATBWasMigrated
    }

    var atb: String? {
        get {
            pixelDataStore.value(forKey: Keys.atb)
        }
        set {
            if let value = newValue {
                pixelDataStore.set(value, forKey: Keys.atb)
            } else {
                assertionFailure("Unexpected ATB removal")
                pixelDataStore.removeValue(forKey: Keys.atb)
            }
        }
    }

    var installDate: Date? {
        get {
            guard let timeInterval: Double = pixelDataStore.value(forKey: Keys.installDate) else { return nil }
            return Date(timeIntervalSinceReferenceDate: timeInterval)
        }
        set {
            if let value = newValue {
                pixelDataStore.set(value.timeIntervalSinceReferenceDate, forKey: Keys.installDate)
            } else {
                assertionFailure("Unexpected ATB installDate removal")
                pixelDataStore.removeValue(forKey: Keys.installDate)
            }
        }
    }

    var searchRetentionAtb: String? {
        get {
            pixelDataStore.value(forKey: Keys.searchRetentionAtb)
        }
        set {
            if let value = newValue {
                pixelDataStore.set(value, forKey: Keys.searchRetentionAtb)
            } else {
                pixelDataStore.removeValue(forKey: Keys.searchRetentionAtb)
            }
        }
    }

    var appRetentionAtb: String? {
        get {
            pixelDataStore.value(forKey: Keys.appRetentionAtb)
        }
        set {
            if let value = newValue {
                pixelDataStore.set(value, forKey: Keys.appRetentionAtb)
            } else {
                pixelDataStore.removeValue(forKey: Keys.appRetentionAtb)
            }
        }
    }

    var variant: String? {
        get {
            pixelDataStore.value(forKey: Keys.variant)
        }
        set {
            if let value = newValue {
                pixelDataStore.set(value, forKey: Keys.variant)
            } else {
                pixelDataStore.removeValue(forKey: Keys.variant)
            }
        }
    }

    var lastAppRetentionRequestDate: Date? {
        get {
            guard let timeInterval: Double = pixelDataStore.value(forKey: Keys.lastAppRetentionRequestDate) else { return nil }
            return Date(timeIntervalSinceReferenceDate: timeInterval)
        }
        set {
            if let value = newValue {
                pixelDataStore.set(value.timeIntervalSinceReferenceDate, forKey: Keys.lastAppRetentionRequestDate)
            } else {
                pixelDataStore.removeValue(forKey: Keys.lastAppRetentionRequestDate)
            }
        }
    }

    var waitlistUnlocked: Bool {
        get {
            guard let booleanStringValue: String = pixelDataStore.value(forKey: Keys.waitlistUnlocked) else { return false }
            return Bool(booleanStringValue) ?? false
        }
        set {
            if newValue == true {
                let booleanAsString = String(newValue)
                pixelDataStore.set(booleanAsString, forKey: Keys.waitlistUnlocked)
            } else {
                // Let the absense of a value represent false, so that anyone digging into the SQLite database won't
                // see a false key and simply set it to true. The database is encrypted, so risk of this is low.
                pixelDataStore.removeValue(forKey: Keys.waitlistUnlocked)
            }
        }
    }

    var autoLockEnabled: Bool {
        get {
            guard let booleanStringValue: String = pixelDataStore.value(forKey: Keys.autoLockEnabled) else {
                return true // Auto-Lock is enabled by default
            }
            return Bool(booleanStringValue) ?? true
        }
        set {
            let booleanAsString = String(newValue)
            pixelDataStore.set(booleanAsString, forKey: Keys.autoLockEnabled)
        }
    }

    var autoLockThreshold: String? {
        get {
            pixelDataStore.value(forKey: Keys.autoLockThreshold)
        }
        set {
            if let value = newValue {
                pixelDataStore.set(value, forKey: Keys.autoLockThreshold)
            } else {
                pixelDataStore.removeValue(forKey: Keys.autoLockThreshold)
            }
        }
    }

}

#if DEBUG

// For use in tests to avoid indirect access of Database.makeDatabase

final class StubStatisticsStore: StatisticsStore {
    var installDate: Date?
    var atb: String?
    var searchRetentionAtb: String?
    var appRetentionAtb: String?
    var variant: String?
    var lastAppRetentionRequestDate: Date?

    var waitlistUnlocked: Bool = false

    var autoLockEnabled: Bool = false
    var autoLockThreshold: String?
}

#endif
