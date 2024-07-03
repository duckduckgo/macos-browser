//
//  DataBrokerProtectionMocks.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class MockAccountManager: AccountManager {
    var hasEntitlementResult: Result<Bool, any Error> = .success(true)

    var delegate: AccountManagerKeychainAccessDelegate?

    var isUserAuthenticated = false

    var accessToken: String? = ""

    var authToken: String?

    var email: String?

    var externalID: String?

    func storeAuthToken(token: String) {
    }

    func storeAccount(token: String, email: String?, externalID: String?) {
    }

    func signOut(skipNotification: Bool) {
    }

    func signOut() {
    }

    func migrateAccessTokenToNewStore() throws {
    }

    func hasEntitlement(forProductName productName: Entitlement.ProductName, cachePolicy: APICachePolicy) async -> Result<Bool, any Error> {
        hasEntitlementResult
    }

    func hasEntitlement(forProductName productName: Entitlement.ProductName) async -> Result<Bool, any Error> {
        hasEntitlementResult
    }

    func updateCache(with entitlements: [Entitlement]) {
    }

    func fetchEntitlements(cachePolicy: APICachePolicy) async -> Result<[Entitlement], any Error> {
        .success([])
    }

    func exchangeAuthTokenToAccessToken(_ authToken: String) async -> Result<String, any Error> {
        .success("")
    }

    func fetchAccountDetails(with accessToken: String) async -> Result<AccountDetails, any Error> {
        .success(AccountDetails(email: "", externalID: ""))
    }

    func checkForEntitlements(wait waitTime: Double, retry retryCount: Int) async -> Bool {
        true
    }
}
