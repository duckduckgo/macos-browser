//
//  FreemiumDBPPixelExperimentManagingTests.swift
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
import SubscriptionTestingUtilities
import Subscription
@testable import DuckDuckGo_Privacy_Browser

final class FreemiumDBPPixelExperimentManagingTests: XCTestCase {

    private var sut: FreemiumDBPPixelExperimentManaging!
    private var mockAccountManager: MockAccountManager!
    private var mockSubscriptionManager: SubscriptionManagerMock!
    private var mockUserDefaults: MockUserDefaults!

    override func setUp() {
       super.setUp()
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
        mockUserDefaults = MockUserDefaults()
        let testLocale = Locale(identifier: "en_US")
        sut = FreemiumDBPPixelExperimentManager(subscriptionManager: mockSubscriptionManager, userDefaults: mockUserDefaults, locale: testLocale)
   }

   override func tearDown() {
       mockSubscriptionManager = nil
       mockUserDefaults = nil
       sut = nil
       super.tearDown()
   }

    // MARK: - Pixel Parameters Tests

    func testPixelParameters_withCohortAndEnrollmentDate_returnsCorrectParameters() {
        // Given
        let cohort = FreemiumDBPPixelExperimentManager.Cohort.treatment
        let enrollmentDate = Date(timeIntervalSince1970: 0) // 19700101
        mockUserDefaults.set(cohort.rawValue, forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.set(enrollmentDate, forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        let parameters = sut.pixelParameters

        // Then
        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?["variant"], cohort.rawValue)
        XCTAssertEqual(parameters?["enrollment"], "19700101")
    }

    func testPixelParameters_withNoCohortAndNoEnrollmentDate_returnsNil() {
        // Given
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        let parameters = sut.pixelParameters

        // Then
        XCTAssertNil(parameters)
    }

    func testPixelParameters_withOnlyCohort_returnsParametersWithVariantOnly() {
        // Given
        let cohort = FreemiumDBPPixelExperimentManager.Cohort.control
        mockUserDefaults.set(cohort.rawValue, forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        let parameters = sut.pixelParameters

        // Then
        XCTAssertNotNil(parameters)
        XCTAssertEqual(parameters?["variant"], cohort.rawValue)
        XCTAssertNil(parameters?["enrollment"])
    }

    func testPixelParameters_withOnlyEnrollmentDate_returnsParametersWithEnrollmentOnly() {
        // Given
        let enrollmentDate = Date(timeIntervalSince1970: 86400) // 19700102
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.set(enrollmentDate, forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        let parameters = sut.pixelParameters

        // Then
        XCTAssertNotNil(parameters)
        XCTAssertNil(parameters?["variant"])
        XCTAssertEqual(parameters?["enrollment"], "19700102")
    }

    // MARK: - Cohort Assignment Tests

    func testAssignUserToCohort_whenUserEligibleAndNotEnrolled_assignsToCohort() {
        // Given
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = nil
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        sut.assignUserToCohort()

        // Then
        let assignedCohortRaw = mockUserDefaults.string(forKey: MockUserDefaults.Keys.experimentCohort)
        let assignedCohort = FreemiumDBPPixelExperimentManager.Cohort(rawValue: assignedCohortRaw ?? "")
        XCTAssertNotNil(assignedCohort)
        XCTAssertTrue(assignedCohort == .control || assignedCohort == .treatment)

        let enrollmentDate = mockUserDefaults.object(forKey: MockUserDefaults.Keys.enrollmentDate) as? Date
        XCTAssertNotNil(enrollmentDate)
    }

    func testAssignUserToCohort_whenUserAlreadyEnrolled_doesNotAssign() {
        // Given
        let existingCohort = FreemiumDBPPixelExperimentManager.Cohort.control
        let existingDate = Date(timeIntervalSince1970: 1000000)
        mockUserDefaults.set(existingCohort.rawValue, forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.set(existingDate, forKey: MockUserDefaults.Keys.enrollmentDate)
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = nil

        // When
        sut.assignUserToCohort()

        // Then
        let assignedCohortRaw = mockUserDefaults.string(forKey: MockUserDefaults.Keys.experimentCohort)
        let assignedCohort = FreemiumDBPPixelExperimentManager.Cohort(rawValue: assignedCohortRaw ?? "")
        XCTAssertEqual(assignedCohort, existingCohort)

        let enrollmentDate = mockUserDefaults.object(forKey: MockUserDefaults.Keys.enrollmentDate) as? Date
        XCTAssertEqual(enrollmentDate, existingDate)
    }

    func testAssignUserToCohort_whenUserNotEligible_dueToSubscription_doesNotAssign() {
        // Given
        mockSubscriptionManager.canPurchase = false
        mockAccountManager.accessToken = "some_token"
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        sut.assignUserToCohort()

        // Then
        let assignedCohortRaw = mockUserDefaults.string(forKey: MockUserDefaults.Keys.experimentCohort)
        XCTAssertNil(assignedCohortRaw)

        let enrollmentDate = mockUserDefaults.object(forKey: MockUserDefaults.Keys.enrollmentDate) as? Date
        XCTAssertNil(enrollmentDate)
    }

    func testAssignUserToCohort_whenUserNotEligible_dueToLocale_doesNotAssign() {
        // Given
        let nonUSLocale = Locale(identifier: "en_GB")
        sut = FreemiumDBPPixelExperimentManager(subscriptionManager: mockSubscriptionManager, userDefaults: mockUserDefaults, locale: nonUSLocale)
        mockSubscriptionManager.canPurchase = true
        mockAccountManager.accessToken = nil
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.experimentCohort)
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        sut.assignUserToCohort()

        // Then
        let assignedCohortRaw = mockUserDefaults.string(forKey: MockUserDefaults.Keys.experimentCohort)
        XCTAssertNil(assignedCohortRaw)

        let enrollmentDate = mockUserDefaults.object(forKey: MockUserDefaults.Keys.enrollmentDate) as? Date
        XCTAssertNil(enrollmentDate)
    }
}

// MARK: - Mock Dependencies

private final class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]

    /// Enum to hold the same keys as defined in the private UserDefaults extension.
    enum Keys {
        static let enrollmentDate = "freemium.dbp.experiment.enrollment-date"
        static let experimentCohort = "freemium.dbp.experiment.cohort"
    }

    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }

    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}
