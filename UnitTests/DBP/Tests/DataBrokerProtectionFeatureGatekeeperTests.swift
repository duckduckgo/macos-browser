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
@testable import BrowserServicesKit
@testable import Subscription
import TestUtils
import SubscriptionTestingUtilities

@testable import DuckDuckGo_Privacy_Browser

final class DataBrokerProtectionFeatureGatekeeperTests: XCTestCase {

    private var sut: DefaultDataBrokerProtectionFeatureGatekeeper!
    private var mockFeatureDisabler: MockFeatureDisabler!
    private var mockFeatureAvailability: MockFeatureAvailability!
    private var mockSubscriptionManager: SubscriptionManagerMock!
    private var mockFreemiumDBPUserStateManager: MockFreemiumDBPUserStateManager!

    private func userDefaults() -> UserDefaults {
        UserDefaults(suiteName: "testing_\(UUID().uuidString)")!
    }

    override func setUpWithError() throws {
        mockFeatureDisabler = MockFeatureDisabler()
        mockFeatureAvailability = MockFeatureAvailability()
        mockSubscriptionManager = SubscriptionManagerMock()
        mockFreemiumDBPUserStateManager = MockFreemiumDBPUserStateManager()
        mockFreemiumDBPUserStateManager.didActivate = false
    }

    func testWhenNoAccessTokenIsFound_butEntitlementIs_andIsNotActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           subscriptionManager: mockSubscriptionManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenIsFound_butNoEntitlementIs_andIsNotActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainer()
        mockFreemiumDBPUserStateManager.didActivate = false
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           subscriptionManager: mockSubscriptionManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenIsFound_butNoEntitlementIs_andIsActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainer()
        mockFreemiumDBPUserStateManager.didActivate = true
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           subscriptionManager: mockSubscriptionManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenAndEntitlementAreNotFound_andIsNotActiveFreemiumUser_thenFeatureIsDisabled() async {
        // Given
        mockFreemiumDBPUserStateManager.didActivate = false
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           subscriptionManager: mockSubscriptionManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAccessTokenAndEntitlementAreFound_andIsNotActiveFreemiumUser_thenFeatureIsEnabled() async {
        // Given
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        mockSubscriptionManager.resultFeatures = [ SubscriptionFeature(entitlement: .dataBrokerProtection, enabled: true) ]
        mockFreemiumDBPUserStateManager.didActivate = false
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           subscriptionManager: mockSubscriptionManager,
                                                           freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        // When
        let result = await sut.arePrerequisitesSatisfied()

        // Then
        XCTAssertTrue(result)
    }

    func testWhenAccessTokenAndEntitlementAreNotFound_andIsActiveFreemiumUser_thenFeatureIsEnabled() async {
        // Given
        mockFreemiumDBPUserStateManager.didActivate = true
        sut = DefaultDataBrokerProtectionFeatureGatekeeper(featureDisabler: mockFeatureDisabler,
                                                           userDefaults: userDefaults(),
                                                           subscriptionAvailability: mockFeatureAvailability,
                                                           subscriptionManager: mockSubscriptionManager,
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

    var isFeatureAvailable: Bool { mockFeatureAvailable }
    var isSubscriptionPurchaseAllowed: Bool { mockSubscriptionPurchaseAllowed }
    var usesUnifiedFeedbackForm: Bool { mockUsesUnifiedFeedbackForm }

    func reset() {
        mockFeatureAvailable = false
        mockSubscriptionPurchaseAllowed = false
        mockUsesUnifiedFeedbackForm = false
    }
}
