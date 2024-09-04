//
//  FreemiumPIRFeatureTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
import Subscription
import BrowserServicesKit
import SubscriptionTestingUtilities
import Freemium

final class FreemiumPIRFeatureTests: XCTestCase {

    private var sut: FreemiumPIRFeature!
    private var mockFeatureFlagger: MockFreemiumPIRFeatureFlagger!
    private var mockAccountManager: MockAccountManager!
    private var mockSubscriptionManager: SubscriptionManagerMock!
    private var mockFreemiumPIRUserStateManagerManager: MockFreemiumPIRUserStateManager!
    private var mockFeatureDisabler: MockFeatureDisabler!

    override func setUpWithError() throws {

        mockFeatureFlagger = MockFreemiumPIRFeatureFlagger()
        mockAccountManager = MockAccountManager()
        let mockSubscriptionService = SubscriptionEndpointServiceMock()
        let mockAuthService = SubscriptionMockFactory.authEndpointService
        let mockStorePurchaseManager = StorePurchaseManagerMock(purchasedProductIDs: ["a", "b"],
                                                        purchaseQueue: [],
                                                        areProductsAvailable: true,
                                                        hasActiveSubscriptionResult: false,
                                                        purchaseSubscriptionResult: .success(""))

        let currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production,
                                                         purchasePlatform: .appStore)

        mockSubscriptionManager = SubscriptionManagerMock(accountManager: mockAccountManager,
                                                          subscriptionEndpointService: mockSubscriptionService,
                                                          authEndpointService: mockAuthService,
                                                          storePurchaseManager: mockStorePurchaseManager,
                                                          currentEnvironment: currentEnvironment,
                                                          canPurchase: false)

        mockFreemiumPIRUserStateManagerManager = MockFreemiumPIRUserStateManager()
        mockFeatureDisabler = MockFeatureDisabler()

    }

    func testWhenFeatureFlagDisabled_thenFreemiumPIRIsNotAvailable() throws {
        // Given
        mockFeatureFlagger.isEnabled = false
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = nil
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenPrivacyProNotAvailable_thenFreemiumPIRIsNotAvailable() throws {
        // Given
        mockFeatureFlagger.isEnabled = true
        mockSubscriptionManager.canPurchase = false
        mockAccountManager.accessToken = nil
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAllConditionsAreNotMet_thenFreemiumPIRIsNotAvailable() throws {
        // Given
        mockFeatureFlagger.isEnabled = false
        mockSubscriptionManager.canPurchase = false
        mockAccountManager.accessToken = "some_token"
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenUserAlreadySubscribed_thenFreemiumPIRIsNotAvailable() throws {
        // Given
        mockFeatureFlagger.isEnabled = true
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = "some_token"
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenUserDidNotOnboard_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumPIRUserStateManagerManager.didOnboard = false
        mockFeatureFlagger.isEnabled = false
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = nil

        // When
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserDidOnboard_andFeatureIsDisabled_andUserCanPurchase_andUserIsNotSubscribed_thenOffboardingIsExecuted() {
        // Given
        mockFreemiumPIRUserStateManagerManager.didOnboard = true
        mockFeatureFlagger.isEnabled = false
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = nil

        // When
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertFalse(mockFreemiumPIRUserStateManagerManager.didOnboard)
        XCTAssertTrue(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserDidOnboard_andFeatureIsDisabled_andUserCanPurchase_andUserIsSubscribed_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumPIRUserStateManagerManager.didOnboard = true
        mockFeatureFlagger.isEnabled = false
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = "some_token"

        // When
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertTrue(mockFreemiumPIRUserStateManagerManager.didOnboard)
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserDidOnboard_andFeatureIsEnabled_andUserCanPurchase_andUserIsNotSubscribed_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumPIRUserStateManagerManager.didOnboard = true
        mockFeatureFlagger.isEnabled = true
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = nil

        // When
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertTrue(mockFreemiumPIRUserStateManagerManager.didOnboard)
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserDidOnboard_andFeatureIsDisabled_andUserCannotPurchase_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumPIRUserStateManagerManager.didOnboard = true
        mockFeatureFlagger.isEnabled = false
        mockSubscriptionManager.canPurchase = false
        mockAccountManager.accessToken = nil

        // When
        sut = DefaultFreemiumPIRFeature(featureFlagger: mockFeatureFlagger,
                                        subscriptionManager: mockSubscriptionManager,
                                        accountManager: mockAccountManager,
                                        freemiumPIRUserStateManager: mockFreemiumPIRUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertTrue(mockFreemiumPIRUserStateManagerManager.didOnboard)
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }
}

final class MockFreemiumPIRFeatureFlagger: FeatureFlagger {
    var isEnabled = false

    func isFeatureOn<F>(forProvider: F) -> Bool where F: BrowserServicesKit.FeatureFlagSourceProviding {
        return isEnabled
    }
}

final class MockFeatureDisabler: DataBrokerProtectionFeatureDisabling {
    var disableAndDeleteWasCalled = false

    func disableAndDelete() {
        disableAndDeleteWasCalled = true
    }

    func reset() {
        disableAndDeleteWasCalled = false
    }
}
