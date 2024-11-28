//
//  FreemiumDBPFeatureTests.swift
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
import Combine
import TestUtils
import SubscriptionTestingUtilities

final class FreemiumDBPFeatureTests: XCTestCase {

    private var sut: FreemiumDBPFeature!
    private var mockPrivacyConfigurationManager: MockPrivacyConfigurationManaging!
    private var mockFreemiumDBPExperimentManager: MockFreemiumDBPExperimentManager!
    private var mockSubscriptionManager: SubscriptionManagerMock!
    private var mockFreemiumDBPUserStateManagerManager: MockFreemiumDBPUserStateManager!
    private var mockFeatureDisabler: MockFeatureDisabler!

    private var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {

        mockPrivacyConfigurationManager = MockPrivacyConfigurationManaging()
        mockFreemiumDBPExperimentManager = MockFreemiumDBPExperimentManager()
        let mockSubscriptionService = SubscriptionEndpointServiceMock()
        let mockStorePurchaseManager = StorePurchaseManagerMock()

        let currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production,
                                                         purchasePlatform: .appStore)

        mockSubscriptionManager = SubscriptionManagerMock()

        mockFreemiumDBPUserStateManagerManager = MockFreemiumDBPUserStateManager()
        mockFeatureDisabler = MockFeatureDisabler()

    }

    func testWhenFeatureFlagDisabled_thenFreemiumDBPIsNotAvailable() throws {
        // Given
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in false }
        mockSubscriptionManager.canPurchase = true
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenFeatureFlagEnabled_thenFreemiumDBPIsAvailable() throws {
        // Given
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true
        mockFreemiumDBPExperimentManager.isTreatment = true
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertTrue(result)
    }

    func testWhenPrivacyProNotAvailable_thenFreemiumDBPIsNotAvailable() throws {
        // Given
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = false
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenAllConditionsAreNotMet_thenFreemiumDBPIsNotAvailable() throws {
        // Given
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in false }
        mockSubscriptionManager.canPurchase = false
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenUserAlreadySubscribed_thenFreemiumDBPIsNotAvailable() throws {
        // Given
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenUserIsInTreatmentCohort_thenFreemiumDBPIsAvailable() throws {
        // Given
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true
        mockFreemiumDBPExperimentManager.isTreatment = true
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertTrue(result)
    }

    func testWhenUserIsNotInTreatmentCohort_thenFreemiumDBPIsNotAvailable() throws {
        // Given
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true
        mockFreemiumDBPExperimentManager.isTreatment = false
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)
        // When
        let result = sut.isAvailable

        // Then
        XCTAssertFalse(result)
    }

    func testWhenUserDidNotActivate_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = false
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in false }
        mockSubscriptionManager.canPurchase = true

        // When
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserdidActivate_andFeatureIsDisabled_andUserCanPurchase_andUserIsNotSubscribed_thenOffboardingIsExecuted() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = true
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in false }
        mockSubscriptionManager.canPurchase = true

        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // When
        sut.subscribeToDependencyUpdates()
        mockPrivacyConfigurationManager.updatesSubject.send()

        // Then
        XCTAssertTrue(mockFreemiumDBPUserStateManagerManager.didCallResetAllState)
        XCTAssertTrue(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserdidActivate_andFeatureIsDisabled_andUserCanPurchase_andUserIsSubscribed_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = true
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in false }
        mockSubscriptionManager.canPurchase = true
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()

        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // When
        sut.subscribeToDependencyUpdates()
        mockPrivacyConfigurationManager.updatesSubject.send()

        // Then
        XCTAssertFalse(mockFreemiumDBPUserStateManagerManager.didCallResetAllState)
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserdidActivate_andFeatureIsEnabled_andUserCanPurchase_andUserIsNotSubscribed_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = true
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true

        // When
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertTrue(mockFreemiumDBPUserStateManagerManager.didActivate)
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenUserdidActivate_andFeatureIsDisabled_andUserCannotPurchase_thenOffboardingIsNotExecuted() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = true
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = false

        // When
        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        // Then
        XCTAssertTrue(mockFreemiumDBPUserStateManagerManager.didActivate)
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    func testWhenFeatureFlagValueChangesToEnabled_thenIsAvailablePublisherEmitsCorrectValue() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = false
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in false }
        mockSubscriptionManager.canPurchase = true
        mockFreemiumDBPExperimentManager.isTreatment = true
        let expectation = XCTestExpectation(description: "isAvailablePublisher emits values")

        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        XCTAssertFalse(sut.isAvailable)

        var isAvailableResult = false
        sut.isAvailablePublisher
            .sink { isAvailable in
                isAvailableResult = isAvailable
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        sut.subscribeToDependencyUpdates()
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockPrivacyConfigurationManager.updatesSubject.send()

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(isAvailableResult)
    }

    func testWhenFeatureFlagValueChangesToDisabled_thenIsAvailablePublisherEmitsCorrectValue() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = true
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true
        mockFreemiumDBPExperimentManager.isTreatment = true
        let expectation = XCTestExpectation(description: "isAvailablePublisher emits values")

        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        XCTAssertTrue(sut.isAvailable)

        var isAvailableResult = false
        sut.isAvailablePublisher
            .sink { isAvailable in
                isAvailableResult = isAvailable
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        sut.subscribeToDependencyUpdates()
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in false }
        mockPrivacyConfigurationManager.updatesSubject.send()

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(isAvailableResult)
    }

    func testSubscriptionStatusChangesToSubscribed_thenIsAvailablePublisherEmitsCorrectValue() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = true
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true
        mockFreemiumDBPExperimentManager.isTreatment = true
        let expectation = XCTestExpectation(description: "isAvailablePublisher emits values")

        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        XCTAssertTrue(sut.isAvailable)

        var isAvailableResult = false
        sut.isAvailablePublisher
            .sink { isAvailable in
                isAvailableResult = isAvailable
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        sut.subscribeToDependencyUpdates()
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        NotificationCenter.default.post(name: .subscriptionDidChange, object: nil)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(isAvailableResult)
    }

    func testSubscriptionStatusChangesToUnsubscribed_thenIsAvailablePublisherEmitsCorrectValue() {
        // Given
        mockFreemiumDBPUserStateManagerManager.didActivate = true
        mockPrivacyConfigurationManager.mockConfig.isSubfeatureKeyEnabled = { _, _ in true }
        mockSubscriptionManager.canPurchase = true
        mockSubscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        mockFreemiumDBPExperimentManager.isTreatment = true
        let expectation = XCTestExpectation(description: "isAvailablePublisher emits values")

        sut = DefaultFreemiumDBPFeature(privacyConfigurationManager: mockPrivacyConfigurationManager,
                                        experimentManager: mockFreemiumDBPExperimentManager,
                                        subscriptionManager: mockSubscriptionManager,
                                        freemiumDBPUserStateManager: mockFreemiumDBPUserStateManagerManager,
                                        featureDisabler: mockFeatureDisabler)

        XCTAssertFalse(sut.isAvailable)

        var isAvailableResult = false
        sut.isAvailablePublisher
            .sink { isAvailable in
                isAvailableResult = isAvailable
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        sut.subscribeToDependencyUpdates()
        mockSubscriptionManager.resultTokenContainer = nil
        NotificationCenter.default.post(name: .subscriptionDidChange, object: nil)

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(isAvailableResult)
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

final class MockFreemiumDBPExperimentManager: FreemiumDBPPixelExperimentManaging {
    var isTreatment = false

    var pixelParameters: [String: String]?

    func assignUserToCohort() {}
}
