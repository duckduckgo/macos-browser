//
//  DataBrokerProtectionSubscriptionManaging.swift
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
    func hasValidEntitlement() async throws -> Bool
}

public final class DataBrokerProtectionSubscriptionManager: DataBrokerProtectionSubscriptionManaging {

    let subscriptionManager: SubscriptionManaging

    public var isUserAuthenticated: Bool {
        (try? subscriptionManager.accountManager.accessToken) != nil
    }

    public var accessToken: String? {
        try? subscriptionManager.accountManager.accessToken
    }

    public init(subscriptionManager: SubscriptionManaging) {
        self.subscriptionManager = subscriptionManager
    }

    public func hasValidEntitlement() async throws -> Bool {
        switch await subscriptionManager.accountManager.hasEntitlement(for: .dataBrokerProtection,
                                                                       cachePolicy: .reloadIgnoringLocalCacheData) {
        case let .success(result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Wrapper Protocols

/// This protocol exists only as a wrapper on top of the AccountManager since it is a concrete type on BSK
public protocol DataBrokerProtectionAccountManaging {
    var accessToken: String? { get throws }
    func hasEntitlement(for cachePolicy: AccountManager.CachePolicy) async -> Result<Bool, Error>
}
