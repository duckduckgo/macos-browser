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

class DataBrokerProtectionAuthenticationManagerTests: XCTestCase {
    var authenticationManager: DataBrokerProtectionAuthenticationManager!
    var redeemUseCase: DataBrokerProtectionRedeemUseCase!
    var subscriptionManager: MockDataBrokerProtectionSubscriptionManaging!

    override func setUp() async throws {
        redeemUseCase = MockRedeemUseCase()
        subscriptionManager = MockDataBrokerProtectionSubscriptionManaging()
    }

    override func tearDown() async throws {
        authenticationManager = nil
        redeemUseCase = nil
        subscriptionManager = nil
    }

    func testUserNotAuthenticatedWhenSubscriptionManagerReturnsFalse() {
        subscriptionManager.userAuthenticatedValue = false

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        XCTAssertEqual(authenticationManager.isUserAuthenticated, false)
    }

    func testEmptyAccessTokenResultsInNilAuthHeader() {
        subscriptionManager.accessTokenValue = nil

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        XCTAssertNil(authenticationManager.getAuthHeader())
    }

    func testUserAuthenticatedWhenSubscriptionManagerReturnsTrue() {
        subscriptionManager.userAuthenticatedValue = true

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        XCTAssertEqual(authenticationManager.isUserAuthenticated, true)
    }

    func testNonEmptyAccessTokenResultsInValidAuthHeader() {
        let accessToken = "validAccessToken"
        subscriptionManager.accessTokenValue = accessToken

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        XCTAssertNotNil(authenticationManager.getAuthHeader())
    }

    func testValidEntitlementCheckWithSuccess() async {
        subscriptionManager.entitlementResultValue = .success(true)

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        let result = await authenticationManager.hasValidEntitlement()

        switch result {
        case .success(let isValid):
            XCTAssertTrue(isValid, "Entitlement check should return true for valid entitlement")
        case .failure(let error):
            XCTFail("Entitlement check should not fail: \(error)")
        }
    }

    func testValidEntitlementCheckWithSuccessFalse() async {
        subscriptionManager.entitlementResultValue = .success(false)

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        let result = await authenticationManager.hasValidEntitlement()

        switch result {
        case .success(let isValid):
            XCTAssertFalse(isValid, "Entitlement check should return false for invalid entitlement")
        case .failure(let error):
            XCTFail("Entitlement check should not fail: \(error)")
        }
    }

    func testValidEntitlementCheckWithFailure() async {
        let testError = NSError(domain: "TestErrorDomain", code: 123, userInfo: nil)
        subscriptionManager.entitlementResultValue = .failure(testError)

        authenticationManager = DataBrokerProtectionAuthenticationManager(redeemUseCase: redeemUseCase,
                                                                          subscriptionManager: subscriptionManager)

        let result = await authenticationManager.hasValidEntitlement()

        switch result {
        case .success:
            XCTFail("Entitlement check should not succeed")
        case .failure(let error):
            XCTAssertEqual(error as NSError, testError, "Entitlement check should return the expected error")
        }
    }

}

final class MockDataBrokerProtectionSubscriptionManaging: DataBrokerProtectionSubscriptionManaging {
    typealias EntitlementResult = Result<Bool, Error>

    var userAuthenticatedValue = false
    var accessTokenValue: String?
    var entitlementResultValue: EntitlementResult = .success(true)

    var isUserAuthenticated: Bool {
        userAuthenticatedValue
    }

    var accessToken: String? {
        accessTokenValue
    }

    func hasValidEntitlement() async -> Result<Bool, Error> {
        entitlementResultValue
    }
}
