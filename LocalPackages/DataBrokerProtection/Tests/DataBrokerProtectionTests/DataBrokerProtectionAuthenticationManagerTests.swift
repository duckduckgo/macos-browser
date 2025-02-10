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
    var subscriptionManager: MockDataBrokerProtectionSubscriptionManaging!

    override func setUp() async throws {
        subscriptionManager = MockDataBrokerProtectionSubscriptionManaging()
    }

    override func tearDown() async throws {
        authenticationManager = nil
        subscriptionManager = nil
    }

    func testUserNotAuthenticatedWhenSubscriptionManagerReturnsFalse() {
        subscriptionManager.userAuthenticatedValue = false

        authenticationManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: subscriptionManager)

        XCTAssertEqual(authenticationManager.isUserAuthenticated, false)
    }

    func testEmptyAccessTokenResultsInNilAuthHeader() {
        subscriptionManager.accessTokenValue = nil

        authenticationManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: subscriptionManager)

        XCTAssertNil(authenticationManager.getAuthHeader())
    }

    func testUserAuthenticatedWhenSubscriptionManagerReturnsTrue() {
        subscriptionManager.userAuthenticatedValue = true

        authenticationManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: subscriptionManager)

        XCTAssertEqual(authenticationManager.isUserAuthenticated, true)
    }

    func testNonEmptyAccessTokenResultsInValidAuthHeader() {
        let accessToken = "validAccessToken"
        subscriptionManager.accessTokenValue = accessToken

        authenticationManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: subscriptionManager)

        XCTAssertNotNil(authenticationManager.getAuthHeader())
    }

    func testValidEntitlementCheckWithSuccess() async {
        subscriptionManager.entitlementResultValue = true

        authenticationManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: subscriptionManager)
        do {
            let result = try await authenticationManager.hasValidEntitlement()
            XCTAssertTrue(result, "Entitlement check should return true for valid entitlement")
        } catch {
            XCTFail("Entitlement check should not fail: \(error)")
        }
    }

    func testValidEntitlementCheckWithSuccessFalse() async {
        subscriptionManager.entitlementResultValue = false

        authenticationManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: subscriptionManager)

        do {
            let result = try await authenticationManager.hasValidEntitlement()
            XCTAssertFalse(result, "Entitlement check should return false for valid entitlement")
        } catch {
            XCTFail("Entitlement check should not fail: \(error)")
        }
    }

    func testValidEntitlementCheckWithFailure() async {
        let mockError = NSError(domain: "TestErrorDomain", code: 123, userInfo: nil)
        subscriptionManager.entitlementError = mockError

        authenticationManager = DataBrokerProtectionAuthenticationManager(subscriptionManager: subscriptionManager)

        do {
            _ = try await authenticationManager.hasValidEntitlement()
            XCTFail("Entitlement check should fail")
        } catch let error as NSError {
            XCTAssertEqual(mockError.domain, error.domain)
            XCTAssertEqual(mockError.code, error.code)
        }
    }
}

final class MockDataBrokerProtectionSubscriptionManaging: DataBrokerProtectionSubscriptionManaging {
    typealias EntitlementResult = Result<Bool, Error>

    var userAuthenticatedValue = false
    var accessTokenValue: String?
    var entitlementResultValue = false
    var entitlementError: Error?

    var isUserAuthenticated: Bool {
        userAuthenticatedValue
    }

    var accessToken: String? {
        accessTokenValue
    }

    func hasValidEntitlement() async throws -> Bool {
        if let error = entitlementError {
            throw error
        }
        return entitlementResultValue
    }
}
