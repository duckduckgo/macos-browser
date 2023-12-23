//
//  WaitlistActivationDateStore.swift
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

enum WaitlistActivationDateStoreSource {
    case netP
    case dbp

    var activationDateKey: String {
        switch self {
        case .netP:
            "com.duckduckgo.network-protection.activation-date"
        case.dbp:
            "com.duckduckgo.dbp.activation-date"
        }
    }

    var lastActiveDateKey: String {
        switch self {
        case .netP:
            "com.duckduckgo.network-protection.last-active-date"
        case .dbp:
            "com.duckduckgo.dbp.last-active-date"
        }
    }
}

protocol WaitlistActivationDateStore {

    func daysSinceActivation(source: WaitlistActivationDateStoreSource) -> Int?
    func daysSinceLastActive(source: WaitlistActivationDateStoreSource) -> Int?

}

struct DefaultWaitlistActivationDateStore: WaitlistActivationDateStore {

    private enum Constants {
        static let networkProtectionActivationDateKey = "com.duckduckgo.network-protection.activation-date"
        static let networkProtectionLastActiveDateKey = "com.duckduckgo.network-protection.last-active-date"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func setActivationDateIfNecessary(source: WaitlistActivationDateStoreSource) {
        if userDefaults.double(forKey: source.activationDateKey) != 0 {
            return
        }

        updateActivationDate(Date(), source: source)
    }

    func daysSinceActivation(source: WaitlistActivationDateStoreSource) -> Int? {
        let timestamp = userDefaults.double(forKey: source.activationDateKey)

        if timestamp == 0 {
            return nil
        }

        let activationDate = Date(timeIntervalSinceReferenceDate: timestamp)
        return daysSince(date: activationDate)
    }

    func updateLastActiveDate(source: WaitlistActivationDateStoreSource) {
        userDefaults.set(Date(), forKey: source.lastActiveDateKey)
    }

    func daysSinceLastActive(source: WaitlistActivationDateStoreSource) -> Int? {
        let timestamp = userDefaults.double(forKey: source.lastActiveDateKey)

        if timestamp == 0 {
            return nil
        }

        let activationDate = Date(timeIntervalSinceReferenceDate: timestamp)
        return daysSince(date: activationDate)
    }

    // MARK: - Resetting

    func removeDates(source: WaitlistActivationDateStoreSource) {
        userDefaults.removeObject(forKey: source.activationDateKey)
        userDefaults.removeObject(forKey: source.lastActiveDateKey)
    }

    // MARK: - Updating

    func updateActivationDate(_ date: Date, source: WaitlistActivationDateStoreSource) {
        userDefaults.set(date.timeIntervalSinceReferenceDate, forKey: source.activationDateKey)
    }

    private func daysSince(date storedDate: Date) -> Int? {
        let numberOfDays = Calendar.current.dateComponents([.day], from: storedDate, to: Date())
        return numberOfDays.day
    }

}
