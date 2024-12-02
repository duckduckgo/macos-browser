//
//  SubscriptionAppStoreRestorerTests.swift
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
import SubscriptionTestingUtilities
@testable import DuckDuckGo_Privacy_Browser
@testable import PixelKit
import PixelKitTestingUtilities
import Common
import enum StoreKit.StoreKitError

@available(macOS 12.0, *)
final class SubscriptionAppStoreRestorerTests: XCTestCase {

    private struct Constants {
        static let userDefaultsSuiteName = "SubscriptionAppStoreRestorerTests"

        static let authToken = UUID().uuidString
        static let accessToken = UUID().uuidString
        static let externalID = UUID().uuidString
        static let email = "dax@duck.com"
    }

    var userDefaults: UserDefaults!
    var pixelKit: PixelKit!
    var uiHandler: SubscriptionUIHandlerMock!

    var accountManager: AccountManagerMock!
    var subscriptionService: SubscriptionEndpointServiceMock!
    var authService: AuthEndpointServiceMock!
    var storePurchaseManager: StorePurchaseManagerMock!
    var subscriptionFeatureMappingCache: SubscriptionFeatureMappingCacheMock!
    var subscriptionEnvironment: SubscriptionEnvironment!

    var subscriptionManager: SubscriptionManagerMock!
    var appStoreRestoreFlow: AppStoreRestoreFlowMock!
    var subscriptionAppStoreRestorer: SubscriptionAppStoreRestorer!

    var pixelsFired = Set<String>()
    var uiEventsHappened: [SubscriptionUIHandlerMock.UIHandlerMockPerformedAction] = []

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

        uiHandler = await SubscriptionUIHandlerMock(didPerformActionCallback: { action in
            self.uiEventsHappened.append(action)
        })

        accountManager = AccountManagerMock()
        subscriptionService = SubscriptionEndpointServiceMock()
        authService = AuthEndpointServiceMock()
        storePurchaseManager = StorePurchaseManagerMock()
        subscriptionFeatureMappingCache = SubscriptionFeatureMappingCacheMock()

        subscriptionEnvironment = SubscriptionEnvironment(serviceEnvironment: .production,
                                                           purchasePlatform: .appStore)

        subscriptionManager = SubscriptionManagerMock(accountManager: accountManager,
                                                      subscriptionEndpointService: subscriptionService,
                                                      authEndpointService: authService,
                                                      storePurchaseManager: storePurchaseManager,
                                                      currentEnvironment: subscriptionEnvironment,
                                                      canPurchase: true,
                                                      subscriptionFeatureMappingCache: subscriptionFeatureMappingCache)
        appStoreRestoreFlow = AppStoreRestoreFlowMock()

        subscriptionAppStoreRestorer = DefaultSubscriptionAppStoreRestorer(subscriptionManager: subscriptionManager,
                                                                           appStoreRestoreFlow: appStoreRestoreFlow,
                                                                           uiHandler: uiHandler)
    }

    override func tearDown() async throws {
        userDefaults = nil

        PixelKit.tearDown()
        pixelKit.clearFrequencyHistoryForAllPixels()

        pixelsFired.removeAll()
        uiEventsHappened.removeAll()

        accountManager = nil
        subscriptionService = nil
        authService = nil
        storePurchaseManager = nil
        subscriptionEnvironment = nil

        subscriptionManager = nil
        appStoreRestoreFlow = nil
        uiHandler = nil

        subscriptionAppStoreRestorer = nil
    }

    // MARK: - Tests for restoreAppStoreSubscription

    func testRestoreAppStoreSubscriptionSuccess() async throws {
        // Given
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .success(())

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreSuccess.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreSuccess.name + "_c"])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    func testRestoreAppStoreSubscriptionWhenUserCancelsSyncAppleID() async throws {
        // Given
        storePurchaseManager.syncAppleIDAccountResultError = StoreKitError.userCancelled

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController])

        XCTAssertTrue(pixelsFired.isEmpty)
    }

    func testRestoreAppStoreSubscriptionSuccessWhenSyncAppleIDFailsButUserProceedsRegardeless() async throws {
        // Given
        storePurchaseManager.syncAppleIDAccountResultError = StoreKitError.unknown
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .success(())

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.appleIDSyncFailed),
                                          .didPresentProgressViewController,
                                          .didDismissProgressViewController])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreSuccess.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreSuccess.name + "_c"])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    // MARK: - Tests for different restore failures

    func testRestoreAppStoreSubscriptionWhenRestoreFailsDueToMissingAccountOrTransactions() async throws {
        // Given
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .failure(.missingAccountOrTransactions)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.subscriptionNotFound),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreFailureNotFound.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreFailureNotFound.name + "_c",
                                  PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                  PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                  PrivacyProPixel.privacyProOfferScreenImpression.name])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    func testRestoreAppStoreSubscriptionWhenRestoreFailsDueToPastTransactionAuthenticationError() async throws {
        // Given
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .failure(.pastTransactionAuthenticationError)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong)])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_c",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_c"])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    func testRestoreAppStoreSubscriptionWhenRestoreFailsDueToFailedToObtainAccessToken() async throws {
        // Given
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .failure(.failedToObtainAccessToken)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong)])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_c",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_c"])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    func testRestoreAppStoreSubscriptionWhenRestoreFailsDueToFailedToFetchAccountDetails() async throws {
        // Given
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .failure(.failedToFetchAccountDetails)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong)])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_c",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_c"])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    func testRestoreAppStoreSubscriptionWhenRestoreFailsDueToFailedToFetchSubscriptionDetails() async throws {
        // Given
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .failure(.failedToFetchSubscriptionDetails)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong)])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_c",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                  PrivacyProPixel.privacyProPurchaseFailure.name + "_c"])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    func testRestoreAppStoreSubscriptionWhenRestoreFailsDueToSubscriptionBeingExpired() async throws {
        // Given
        appStoreRestoreFlow.restoreAccountFromPastPurchaseResult = .failure(.subscriptionExpired(accountDetails: .init(authToken: Constants.authToken,
                                                                                                                       accessToken: Constants.accessToken,
                                                                                                                       externalID: Constants.externalID,
                                                                                                                       email: Constants.email)) )
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        await subscriptionAppStoreRestorer.restoreAppStoreSubscription()

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.subscriptionInactive),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])

        let expectedPixels = Set([PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_d",
                                  PrivacyProPixel.privacyProRestorePurchaseStoreFailureOther.name + "_c",
                                  PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                  PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                  PrivacyProPixel.privacyProOfferScreenImpression.name])

        XCTAssertTrue(expectedPixels.isSubset(of: pixelsFired))
        XCTAssertTrue(assertNoOtherPrivacyProPixelsExcept(expectedPixels), "Unexpected Privacy Pro pixels fired")
    }

    private func assertNoOtherPrivacyProPixelsExcept(_ expectedPixels: Set<String>) -> Bool {
#if APPSTORE
        let appDistribution = "store"
#else
        let appDistribution = "direct"
#endif
        let privacyProPixelPrefix = "m_mac_\(appDistribution)_privacy-pro"

        let otherPixels = pixelsFired.subtracting(expectedPixels)
        return !otherPixels.contains { $0.hasPrefix(privacyProPixelPrefix) }
    }
}
