//
//  FreemiumPIRUserState.swift
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
import Subscription

/// `FreemiumPIRUserState` types provide access to Freemium PIR-related state
public protocol FreemiumPIRUserState {
    var didOnboard: Bool { get set }
    var isActiveUser: Bool { get }
}

/// Default implementation of `FreemiumPIRUserState`. `UserDefaults` is used as underlying storage.
public final class DefaultFreemiumPIRUserState: FreemiumPIRUserState {

    private let userDefaults: UserDefaults
    private let accountManager: AccountManager
    private let key = "macos.browser.freemium.pir.did.onboard"

    public var didOnboard: Bool {
        get {
            userDefaults.bool(forKey: key)
        } set {
            userDefaults.set(newValue, forKey: key)
        }
    }

    /// Logic is based on `didOnboard` && `accountManager.isUserAuthenticated`
    /// A user can only be a current freemium user is they onboarded and DON'T have a subscription
    public var isActiveUser: Bool {
        didOnboard && !accountManager.isUserAuthenticated
    }

    /// Initializes a `DefaultFreemiumPIRState` instance
    /// Note: The `UserDefaults` parameter will be used to get and set state values. If creating and accessing this type from
    /// multiple places, you must ensure you always pass the same `UserDefaults` instance to get consistent results.
    /// - Parameters:
    ///   - userDefaults: The `UserDefaults` parameter will be used to get and set state values.
    ///   - accountManager: the `AccountManager` parameter is used to check if a user has a privacy pro subscription
    public init(userDefaults: UserDefaults,
                accountManager: AccountManager) {
        self.userDefaults = userDefaults
        self.accountManager = accountManager
    }
}