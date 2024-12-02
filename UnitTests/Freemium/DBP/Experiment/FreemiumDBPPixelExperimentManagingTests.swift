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
        let mockAuthService = AuthEndpointServiceMock()
        let mockStorePurchaseManager = StorePurchaseManagerMock()
        let mockSubscriptionFeatureMappingCache = SubscriptionFeatureMappingCacheMock()

        let currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production,
                                                         purchasePlatform: .appStore)

        mockSubscriptionManager = SubscriptionManagerMock(accountManager: mockAccountManager,
                                                          subscriptionEndpointService: mockSubscriptionService,
                                                          authEndpointService: mockAuthService,
                                                          storePurchaseManager: mockStorePurchaseManager,
                                                          currentEnvironment: currentEnvironment,
                                                          canPurchase: false,
                                                          subscriptionFeatureMappingCache: mockSubscriptionFeatureMappingCache)
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

    // MARK: - isTreatment Property Tests

    func testIsTreatment_whenCohortIsTreatment_returnsTrue() {
        // Given
        mockUserDefaults.set("treatment", forKey: MockUserDefaults.Keys.experimentCohort)

        // When
        let isTreatment = sut.isTreatment

        // Then
        XCTAssertTrue(isTreatment)
    }

    func testIsTreatment_whenCohortIsControl_returnsFalse() {
        // Given
        mockUserDefaults.set("control", forKey: MockUserDefaults.Keys.experimentCohort)

        // When
        let isTreatment = sut.isTreatment

        // Then
        XCTAssertFalse(isTreatment)
    }

    func testIsTreatment_whenCohortIsNil_returnsFalse() {
        // Given
        mockUserDefaults.removeObject(forKey: MockUserDefaults.Keys.experimentCohort)

        // When
        let isTreatment = sut.isTreatment

        // Then
        XCTAssertFalse(isTreatment)
    }

    // MARK: - Pixel Parameter Tests

    func testReturnsCorrectEnrollmentDateParameter_whenUserIsEnrolled() throws {
        // Given
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())
        mockUserDefaults.set(twoDaysAgo, forKey: MockUserDefaults.Keys.enrollmentDate)

        // When
        let parameters = sut.pixelParameters

        // Then
        XCTAssertEqual("2", parameters?["daysEnrolled"])
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
