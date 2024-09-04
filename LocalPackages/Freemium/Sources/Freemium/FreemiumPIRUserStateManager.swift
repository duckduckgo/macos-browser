//
//  FreemiumPIRUserStateManager.swift
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

/// `FreemiumPIRUserStateManager` types provide access to Freemium PIR-related state
public protocol FreemiumPIRUserStateManager {
    var didOnboard: Bool { get set }

}

/// Default implementation of `FreemiumPIRUserStateManager`. `UserDefaults` is used as underlying storage.
public final class DefaultFreemiumPIRUserStateManager: FreemiumPIRUserStateManager {

    private enum Keys {
        static let didOnboard = "macos.browser.freemium.pir.did.onboard"
    }

    private let userDefaults: UserDefaults
    private let key = "macos.browser.freemium.pir.did.onboard"

    public var didOnboard: Bool {
        get {
            userDefaults.bool(forKey: Keys.didOnboard)
        } set {
            userDefaults.set(newValue, forKey: Keys.didOnboard)
        }
    }

    /// Initializes a `DefaultFreemiumPIRState` instance
    ///
    /// Note 1: The `UserDefaults` parameter will be used to get and set state values. If creating and accessing this type from
    /// multiple places, you must ensure you always pass the same `UserDefaults` instance to get consistent results.
    /// .
    /// - Parameters:
    ///   - userDefaults: The `UserDefaults` parameter will be used to get and set state values.
    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}
