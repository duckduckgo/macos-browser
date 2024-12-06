//
//  DataBrokerProtectionAuthenticationManagerTests.swift
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

import XCTest
@testable import DataBrokerProtection
import Subscription
import SubscriptionTestingUtilities
import Networking
import TestUtils

class DataBrokerProtectionAuthenticationManagerTests: XCTestCase {
    var authenticationManager: DataBrokerProtectionAuthenticationManager!
    var redeemUseCase: DataBrokerProtectionRedeemUseCase!
    var subscriptionManager: SubscriptionManagerMock!

    override func setUp() async throws {
        redeemUseCase = MockRedeemUseCase()
        subscriptionManager = SubscriptionManagerMock()
    }

    override func tearDown() async throws {
        authenticationManager = nil
        redeemUseCase = nil
        subscriptionManager = nil
    }

    func testUserNotAuthenticatedWhenSubscriptionManagerReturnsFalse() {
        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)
        XCTAssertEqual(authenticationManager.isUserAuthenticated, false)
    }

    func testEmptyAccessTokenResultsInNilAuthHeader() {
        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)
        XCTAssertNil(authenticationManager.getAuthHeader())
    }

    func testUserAuthenticatedWhenSubscriptionManagerReturnsTrue() {
        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainer()
        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        XCTAssertEqual(authenticationManager.isUserAuthenticated, true)
    }

    func testNonEmptyAccessTokenResultsInValidAuthHeader() {
        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainer()

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        XCTAssertNotNil(authenticationManager.getAuthHeader())
    }

    func testValidEntitlementCheckWithSuccess() async {
        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)
        let result = await authenticationManager.hasValidEntitlement()
        XCTAssertTrue(result, "Entitlement check should return true for valid entitlement")
    }

    func testValidEntitlementCheckWithSuccessFalse() async {
        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainer()
        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        let result = await authenticationManager.hasValidEntitlement()
        XCTAssertFalse(result, "Entitlement check should return false for valid entitlement")
    }
}
