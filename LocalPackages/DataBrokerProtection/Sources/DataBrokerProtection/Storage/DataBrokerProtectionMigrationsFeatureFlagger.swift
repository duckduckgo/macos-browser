//
//  DataBrokerProtectionMigrationsFeatureFlagger.swift
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

import Foundation

/// Conforming types provide a `isUserIn` method to check if a user is part of the specified % feature rollout
protocol DataBrokerProtectionMigrationsFeatureFlagger {
    func isUserIn(percent: Int) -> Bool
}

final class DefaultDataBrokerProtectionMigrationsFeatureFlagger: DataBrokerProtectionMigrationsFeatureFlagger {

    enum Constants {
        static let v3MigrationFeatureFlagValue = "macos.browser.data-broker-protection.v3MigrationFeatureFlagValue"
    }

    private var userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .dbp) {
        self.userDefaults = userDefaults
    }

    /// Checks if a user is part of the specified % feature rollout
    /// - Parameter percent: Percentage
    /// - Returns: True or false
    func isUserIn(percent: Int) -> Bool {

        guard let storedNumber = storedRandomNumber else {

            let generatedNumber = Int.random(in: 1...100)
            storedRandomNumber = generatedNumber

            return generatedNumber.isIn(percent: percent)
        }

        return storedNumber.isIn(percent: percent)
    }
}

private extension DefaultDataBrokerProtectionMigrationsFeatureFlagger {

    /// Retrieves its value from, and stores it to, `UserDefaults`
    var storedRandomNumber: Int? {
        get {
            userDefaults.object(forKey: Constants.v3MigrationFeatureFlagValue) as? Int
        }
        set {
            userDefaults.set(newValue, forKey: Constants.v3MigrationFeatureFlagValue)
        }
    }
}

private extension Int {

    /// Checks if a number is less than or equal to a % value
    /// - Parameter percent: Percentage
    /// - Returns: True or false
    func isIn(percent: Int) -> Bool {
        self <= percent
    }
}
