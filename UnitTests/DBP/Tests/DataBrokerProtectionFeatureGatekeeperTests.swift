//
//  DataBrokerProtectionFeatureGatekeeperTests.swift
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

import XCTest
import BrowserServicesKit
import Subscription

@testable import DuckDuckGo_Privacy_Browser

final class DataBrokerProtectionFeatureGatekeeperTests: XCTestCase {

    private var sut: DefaultDataBrokerProtectionFeatureGatekeeper!
    private var mockFeatureDisabler: MockFeatureDisabler!
    private var mockFeatureAvailability: MockFeatureAvailability!
    private var mockAccountManager: MockAccountManager!
    private var mockFreemiumDBPUserStateManager: MockFreemiumDBPUserStateManager!

    private func userDefaults() -> UserDefaults {
        UserDefaults(suiteName: "testing_\(UUID().uuidString)")!
    }

    override func setUpWithError() throws {
        mockFeatureDisabler = MockFeatureDisabler()
        mockFeatureAvailability = MockFeatureAvailability()
        mockAccountManager = MockAccountManager()
        mockFreemiumDBPUserStateManager = MockFreemiumDBPUserStateManager()
        mockFreemiumDBPUserStateManager.didActivate = false
    }

    func testWhenNoAccessTokenIsFound_butEntitlementIs_andIsNotActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        mockAccountManager.accessToken = nil
        mockAccountManager.hasEntitlementResult = .success(true)
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           accountManager: mockAccountManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenIsFound_butNoEntitlementIs_andIsNotActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        mockAccountManager.accessToken = "token"
        mockAccountManager.hasEntitlementResult = .failure(MockError.someError)
        mockFreemiumDBPUserStateManager.didActivate = false
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           accountManager: mockAccountManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenIsFound_butNoEntitlementIs_andIsActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        mockAccountManager.accessToken = "token"
        mockAccountManager.hasEntitlementResult = .failure(MockError.someError)
        mockFreemiumDBPUserStateManager.didActivate = true
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           accountManager: mockAccountManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenAndEntitlementAreNotFound_andIsNotActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        mockAccountManager.accessToken = nil
        mockAccountManager.hasEntitlementResult = .failure(MockError.someError)
        mockFreemiumDBPUserStateManager.didActivate = false
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           accountManager: mockAccountManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenAndEntitlementAreFound_andIsNotActiveFreemiumUser_thenFeatureIsEnabled() async {
        // Given
        mockAccountManager.accessToken = "token"
        mockAccountManager.hasEntitlementResult = .success(true)
        mockFreemiumDBPUserStateManager.didActivate = false
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           accountManager: mockAccountManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertTrue(result)
    }

    func testWhenAccessTokenAndEntitlementAreNotFound_andIsActiveFreemiumUser_thenFeatureIsEnabled() async {
        // Given
        mockAccountManager.accessToken = nil
        mockAccountManager.hasEntitlementResult = .failure(MockError.someError)
        mockFreemiumDBPUserStateManager.didActivate = true
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           accountManager: mockAccountManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertTrue(result)
    }
}

private enum MockError: Error {
    case someError
}

private class MockFeatureAvailability: SubscriptionFeatureAvailability {
    var mockFeatureAvailable: Bool = false
    var mockSubscriptionPurchaseAllowed: Bool = false
    var mockUsesUnifiedFeedbackForm: Bool = false

    var isSubscriptionPurchaseAllowed: Bool { mockSubscriptionPurchaseAllowed }
    var usesUnifiedFeedbackForm: Bool { mockUsesUnifiedFeedbackForm }

    func reset() {
        mockFeatureAvailable = false
        mockSubscriptionPurchaseAllowed = false
        mockUsesUnifiedFeedbackForm = false
    }
}
