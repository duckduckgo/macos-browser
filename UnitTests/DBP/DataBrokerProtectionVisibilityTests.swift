//
//  DataBrokerProtectionVisibilityTests.swift
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

final class DataBrokerProtectionVisibilityTests: XCTestCase {

    private var mockFeatureDisabler: MockFeatureDisabler!
    private var mockFeatureAvailability: MockFeatureAvailability!
    private var waitlistStorage: MockWaitlistStorage!

    private func userDefaults() -> UserDefaults {
        UserDefaults(suiteName: "testing_\(UUID().uuidString)")!
    }

    override func setUpWithError() throws {
        mockFeatureDisabler = MockFeatureDisabler()
        mockFeatureAvailability = MockFeatureAvailability()
        waitlistStorage = MockWaitlistStorage()
    }

    override func tearDownWithError() throws {
        mockFeatureDisabler.reset()
        mockFeatureAvailability.reset()
        waitlistStorage.deleteWaitlistState()
    }

    /// Waitlist is OFF, Not redeemed
    /// PP flag is OF
    func testWhenWaitlistHasNoInviteCodeAndFeatureDisabled_thenCleanUpIsNotCalled() throws {
        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility(featureDisabler: mockFeatureDisabler,
                                                                             userDefaults: userDefaults(),
                                                                             waitlistStorage: waitlistStorage,
                                                                             subscriptionAvailability: mockFeatureAvailability)

        XCTAssertFalse(featureVisibility.cleanUpDBPForPrivacyProIfNecessary())
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    /// Waitlist is OFF, Not redeemed
    /// PP flag is ON
    func testWhenWaitlistHasNoInviteCodeAndFeatureEnabled_thenCleanUpIsNotCalled() throws {
        mockFeatureAvailability.mockFeatureAvailable = true

        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility(featureDisabler: mockFeatureDisabler,
                                                                             userDefaults: userDefaults(),
                                                                             waitlistStorage: waitlistStorage,
                                                                             subscriptionAvailability: mockFeatureAvailability)

        XCTAssertFalse(featureVisibility.cleanUpDBPForPrivacyProIfNecessary())
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    /// Waitlist is ON, redeemed
    /// PP flag is OFF
    func testWhenWaitlistHasInviteCodeAndFeatureDisabled_thenCleanUpIsNotCalled() throws {
        waitlistStorage.store(waitlistToken: "potato")
        waitlistStorage.store(inviteCode: "banana")
        waitlistStorage.store(waitlistTimestamp: 123)

        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility(featureDisabler: mockFeatureDisabler,
                                                                             userDefaults: userDefaults(),
                                                                             waitlistStorage: waitlistStorage,
                                                                             subscriptionAvailability: mockFeatureAvailability)

        XCTAssertFalse(featureVisibility.cleanUpDBPForPrivacyProIfNecessary())
        XCTAssertFalse(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    /// Waitlist is ON, redeemed
    /// PP flag is ON
    func testWhenWaitlistHasInviteCodeAndFeatureEnabled_thenCleanUpIsCalled() throws {
        waitlistStorage.store(waitlistToken: "potato")
        waitlistStorage.store(inviteCode: "banana")
        waitlistStorage.store(waitlistTimestamp: 123)
        mockFeatureAvailability.mockFeatureAvailable = true

        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility(featureDisabler: mockFeatureDisabler,
                                                                             userDefaults: userDefaults(),
                                                                             waitlistStorage: waitlistStorage,
                                                                             subscriptionAvailability: mockFeatureAvailability)

        XCTAssertTrue(featureVisibility.cleanUpDBPForPrivacyProIfNecessary())
        XCTAssertTrue(mockFeatureDisabler.disableAndDeleteWasCalled)
    }

    /// Waitlist is ON, redeemed
    /// PP flag is ON
    func testWhenWaitlistHasInviteCodeAndFeatureEnabled_thenCleanUpIsCalledTwice() throws {
        waitlistStorage.store(waitlistToken: "potato")
        waitlistStorage.store(inviteCode: "banana")
        waitlistStorage.store(waitlistTimestamp: 123)
        mockFeatureAvailability.mockFeatureAvailable = true

        let featureVisibility = DefaultDataBrokerProtectionFeatureVisibility(featureDisabler: mockFeatureDisabler,
                                                                             userDefaults: userDefaults(),
                                                                             waitlistStorage: waitlistStorage,
                                                                             subscriptionAvailability: mockFeatureAvailability)

        XCTAssertTrue(featureVisibility.cleanUpDBPForPrivacyProIfNecessary())
        XCTAssertTrue(mockFeatureDisabler.disableAndDeleteWasCalled)

        XCTAssertFalse(featureVisibility.cleanUpDBPForPrivacyProIfNecessary())
    }
}

private class MockFeatureDisabler: DataBrokerProtectionFeatureDisabling {
    var disableAndDeleteWasCalled = false

    func disableAndDelete() {
        disableAndDeleteWasCalled = true
    }

    func reset() {
        disableAndDeleteWasCalled = false
    }
}

private class MockFeatureAvailability: SubscriptionFeatureAvailability {
    var mockFeatureAvailable: Bool = false
    var mockSubscriptionPurchaseAllowed: Bool = false

    var isFeatureAvailable: Bool { mockFeatureAvailable }
    var isSubscriptionPurchaseAllowed: Bool { mockSubscriptionPurchaseAllowed }

    func reset() {
        mockFeatureAvailable = false
        mockSubscriptionPurchaseAllowed = false
    }
}
