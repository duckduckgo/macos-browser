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

public protocol DataBrokerProtectionAccountManaging {
    var accessToken: String? { get }
    func hasEntitlement(for cachePolicy: AccountManager.CachePolicy) async -> Result<Bool, Error>
}

public protocol DataBrokerProtectionSubscriptionHandling {
    var isUserAuthenticated: Bool { get }
    var accessToken: String? { get }
    func hasValidEntitlement() async -> Result<Bool, Error>
}

public final class DataBrokerProtectionSubscriptionHandler: DataBrokerProtectionSubscriptionHandling {
    private let settings: DataBrokerProtectionSettings
    private let accountManager: DataBrokerProtectionAccountManaging

    public var isUserAuthenticated: Bool {
        accountManager.accessToken != nil
    }

    public var accessToken: String? {
        accountManager.accessToken
    }

    public init(settings: DataBrokerProtectionSettings = DataBrokerProtectionSettings(),
                accountManager: DataBrokerProtectionAccountManaging) {
        self.settings = settings
        self.accountManager = accountManager
    }

    public func hasValidEntitlement() async -> Result<Bool, Error> {
        SubscriptionPurchaseEnvironment.currentServiceEnvironment = settings.selectedEnvironment == .production ? .production : .staging

        return await accountManager.hasEntitlement(for: .reloadIgnoringLocalCacheData)
    }
}
