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

    var activationDateKey: String {
        switch self {
        case .netP: return "com.duckduckgo.network-protection.activation-date"
        }
    }

    var lastActiveDateKey: String {
        switch self {
        case .netP: return "com.duckduckgo.network-protection.last-active-date"
        }
    }
}

protocol WaitlistActivationDateStore {

    func daysSinceActivation() -> Int?
    func daysSinceLastActive() -> Int?

}

struct DefaultWaitlistActivationDateStore: WaitlistActivationDateStore {

    private let source: WaitlistActivationDateStoreSource
    private let userDefaults: UserDefaults

    init(source: WaitlistActivationDateStoreSource) {
        self.source = source
        switch source {
        case.netP:
            self.userDefaults = .netP
        }
    }

    func setActivationDateIfNecessary() {
        if userDefaults.double(forKey: source.activationDateKey) != 0 {
            return
        }

        updateActivationDate(Date())
    }

    func daysSinceActivation() -> Int? {
        let timestamp = userDefaults.double(forKey: source.activationDateKey)

        if timestamp == 0 {
            return nil
        }

        let activationDate = Date(timeIntervalSinceReferenceDate: timestamp)
        return daysSince(date: activationDate)
    }

    func updateLastActiveDate() {
        userDefaults.set(Date(), forKey: source.lastActiveDateKey)
    }

    func daysSinceLastActive() -> Int? {
        let timestamp = userDefaults.double(forKey: source.lastActiveDateKey)

        if timestamp == 0 {
            return nil
        }

        let activationDate = Date(timeIntervalSinceReferenceDate: timestamp)
        return daysSince(date: activationDate)
    }

    // MARK: - Resetting

    func removeDates() {
        userDefaults.removeObject(forKey: source.activationDateKey)
        userDefaults.removeObject(forKey: source.lastActiveDateKey)
    }

    // MARK: - Updating

    func updateActivationDate(_ date: Date) {
        userDefaults.set(date.timeIntervalSinceReferenceDate, forKey: source.activationDateKey)
    }

    private func daysSince(date storedDate: Date) -> Int? {
        let numberOfDays = Calendar.current.dateComponents([.day], from: storedDate, to: Date())
        return numberOfDays.day
    }

}
