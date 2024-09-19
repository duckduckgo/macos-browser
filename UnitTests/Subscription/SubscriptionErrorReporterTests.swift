//
//  SubscriptionErrorReporterTests.swift
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
@testable import Subscription
@testable import DuckDuckGo_Privacy_Browser
@testable import PixelKit
import PixelKitTestingUtilities

final class SubscriptionErrorReporterTests: XCTestCase {

    private struct Constants {
        static let userDefaultsSuiteName = "SubscriptionErrorReporterTests"
    }

    var userDefaults: UserDefaults!
    var pixelKit: PixelKit!

    var reporter: SubscriptionErrorReporter! = DefaultSubscriptionErrorReporter()

    var pixelsFired = Set<String>()

    override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: Constants.userDefaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: Constants.userDefaultsSuiteName)

        pixelKit = PixelKit(dryRun: false,
                            appVersion: "1.0.0",
                            defaultHeaders: [:],
                            defaults: userDefaults) { pixelName, _, _, _, _, _ in
            self.pixelsFired.insert(pixelName)
        }
        pixelKit.clearFrequencyHistoryForAllPixels()
        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        reporter = DefaultSubscriptionErrorReporter()
    }

    override func tearDown() async throws {
        userDefaults = nil

        PixelKit.tearDown()
        pixelKit.clearFrequencyHistoryForAllPixels()

        pixelsFired.removeAll()

        reporter = nil
    }

    // MARK: - Tests for various subscription errors

    func testReporterForPurchaseFailedError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .purchaseFailed

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c"])
    }

    func testReporterForMissingEntitlementsError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .missingEntitlements

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_c"])
    }

    func testReporterForFailedToGetSubscriptionOptionsError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .failedToGetSubscriptionOptions

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c"])
    }

    func testReporterForFailedToSetSubscriptionError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .failedToSetSubscription

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_c"])
    }

    func testReporterForFailedToRestoreFromEmailError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .failedToRestoreFromEmail

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        let expectedPixels = Set([PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_d",
                                  PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_c"])
        XCTAssertEqual(pixelsFired, expectedPixels)
    }

    func testReporterForFailedToRestoreFromEmailSubscriptionInactiveError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .failedToRestoreFromEmailSubscriptionInactive

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_c"])
    }

    func testReporterForFailedToRestorePastPurchaseError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .failedToRestorePastPurchase

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c"])
    }

    func testReporterForSubscriptionNotFoundError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .subscriptionNotFound

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProRestorePurchaseStoreFailureNotFound.name + "_d",
                                     PrivacyProPixel.privacyProRestorePurchaseStoreFailureNotFound.name + "_c"])
    }

    func testReporterForSubscriptionExpiredError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .subscriptionExpired

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c"])
    }

    func testReporterForHasActiveSubscriptionError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .hasActiveSubscription

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_c"])
    }

    func testReporterForCancelledByUserError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .cancelledByUser

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([])
    }

    func testReporterForAccountCreationFailedError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .accountCreationFailed

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseFailureAccountNotCreated.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureAccountNotCreated.name + "_c"])
    }

    func testReporterForActiveSubscriptionAlreadyPresentError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .activeSubscriptionAlreadyPresent

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([])
    }

    func testReporterForGeneralError() async throws {
        // Given
        let errorToBeHandled: SubscriptionError = .generalError

        // When
        reporter.report(subscriptionActivationError: errorToBeHandled)

        // Then
        XCTAssertPrivacyPixelsFired([])
    }

    public func XCTAssertPrivacyPixelsFired(_ pixels: [String], file: StaticString = #file, line: UInt = #line) {
        let pixelsFired = Set(pixelsFired)
        let expectedPixels = Set(pixels)

        // Assert expected pixels were fired
        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired),
                      "Expected Privacy Pro pixels were not fired: \(expectedPixels.subtracting(pixelsFired))",
                      file: file,
                      line: line)

        // Assert no other Privacy Pro pixels were fired except the expected
#if APPSTORE
        let privacyProPixelPrefix = "m_mac_store_privacy-pro"
#else
        let privacyProPixelPrefix = "m_mac_direct_privacy-pro"
#endif
        let otherPixels = pixelsFired.subtracting(expectedPixels)
        let otherPrivacyProPixels = otherPixels.filter { $0.hasPrefix(privacyProPixelPrefix) }
        XCTAssertTrue(otherPrivacyProPixels.isEmpty,
                      "Unexpected Privacy Pro pixels fired: \(otherPrivacyProPixels)",
                      file: file,
                      line: line)
    }
}
