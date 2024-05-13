//
//  SubscriptionOriginStore.swift
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

/// A protocol defining the storage for the Privacy Pro subscription attribution information.
protocol SubscriptionOriginStorage: AnyObject {
    /// The subscription origin information.
    var origin: String? { get set }
}

/// A class that provides storage for the Privacy Pro subscription attribution information.
final class SubscriptionOriginStore: SubscriptionOriginStorage {
    enum Keys {
        static let privacyProSubscriptionOriginKey = "subscription.origin"
    }

    private let userDefaults: UserDefaults

    /// Initializes a `SubscriptionOriginStore` instance with the specified UserDefaults instance.
    ///
    /// - Parameter userDefaults: The UserDefaults instance to use for storage.
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var origin: String? {
        get {
            userDefaults.string(forKey: Keys.privacyProSubscriptionOriginKey)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.privacyProSubscriptionOriginKey)
        }
    }
}
