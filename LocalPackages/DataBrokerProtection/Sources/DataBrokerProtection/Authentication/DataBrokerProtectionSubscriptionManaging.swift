//
//  DataBrokerProtectionSubscriptionHandling.swift
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
import Common

public protocol DataBrokerProtectionSubscriptionManaging {
    var isUserAuthenticated: Bool { get }
    var accessToken: String? { get }
    func hasValidEntitlement() async -> Result<Bool, Error>
}

public final class DataBrokerProtectionSubscriptionManager: DataBrokerProtectionSubscriptionManaging {
    private let accountManager: DataBrokerProtectionAccountManaging
    private let environmentManager: DataBrokerProtectionSubscriptionPurchaseEnvironmentManaging

    public var isUserAuthenticated: Bool {
        accountManager.accessToken != nil
    }

    public var accessToken: String? {
        accountManager.accessToken
    }

    public init(accountManager: DataBrokerProtectionAccountManaging,
                environmentManager: DataBrokerProtectionSubscriptionPurchaseEnvironmentManaging) {
        self.accountManager = accountManager
        self.environmentManager = environmentManager
    }

    public func hasValidEntitlement() async -> Result<Bool, Error> {
        environmentManager.updateEnvironment()
        return await accountManager.hasEntitlement(for: .reloadIgnoringLocalCacheData)
    }
}

// MARK: - Wrapper Protocols

/// This protocol exists only as a wrapper on top of the AccountManager since it is a concrete type on BSK
public protocol DataBrokerProtectionAccountManaging {
    var accessToken: String? { get }
    func hasEntitlement(for cachePolicy: AccountManager.CachePolicy) async -> Result<Bool, Error>
}

