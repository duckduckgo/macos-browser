//
//  SubscriptionPagesUseSubscriptionFeatureForStripeTests.swift
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
@testable import Subscription
import SubscriptionTestingUtilities
import Common
import WebKit
import UserScript
@testable import PixelKit
import PixelKitTestingUtilities
import os.log
import Networking
import TestUtils

@available(macOS 12.0, *)
final class SubscriptionPagesUseSubscriptionFeatureForStripeTests: XCTestCase {

    private struct Constants {
        static let userDefaultsSuiteName = "SubscriptionPagesUseSubscriptionFeatureTests"

        static let authToken = UUID().uuidString
        static let accessToken = UUID().uuidString
        static let externalID = UUID().uuidString

        static let email = "dax@duck.com"

        static let entitlements: [SubscriptionEntitlement] = [.dataBrokerProtection,
                                                              .identityTheftRestoration,
                                                              .networkProtection]

        static let mostRecentTransactionJWS = "dGhpcyBpcyBub3QgYSByZWFsIEFw(...)cCBTdG9yZSB0cmFuc2FjdGlvbiBKV1M="

        static let productItems = [GetProductsItem(productId: "1",
                                                   productLabel: "Monthly subscription",
                                                   billingPeriod: "monthly",
                                                   price: "9",
                                                   currency: "USD"),
                                   GetProductsItem(productId: "2",
                                                   productLabel: "Annual subscription",
                                                   billingPeriod: "yearly",
                                                   price: "99",
                                                   currency: "USD")]

        static let subscriptionOptions = SubscriptionOptions(
            platform: SubscriptionPlatformName.stripe,
            options: [
                SubscriptionOption(id: "1", cost: SubscriptionOptionCost(displayPrice: "$9.00", recurrence: "monthly")),
                SubscriptionOption(id: "2", cost: SubscriptionOptionCost(displayPrice: "$99.00", recurrence: "yearly"))
            ],
            availableEntitlements: [.networkProtection, .dataBrokerProtection, .identityTheftRestoration])
        static let mockParams: [String: String] = [:]
        @MainActor static let mockScriptMessage = MockWKScriptMessage(name: "", body: "", webView: WKWebView() )
    }

    var userDefaults: UserDefaults!
    var broker: UserScriptMessageBroker = UserScriptMessageBroker(context: "testBroker")
    var uiHandler: SubscriptionUIHandlerMock!
    var pixelKit: PixelKit!

    var subscriptionManager: SubscriptionManagerMock!

    var storePurchaseManager: StorePurchaseManagerMock!
    var subscriptionEnvironment: SubscriptionEnvironment!
    var appStorePurchaseFlow: AppStorePurchaseFlow!
    var appStoreRestoreFlow: AppStoreRestoreFlow!
    var stripePurchaseFlow: StripePurchaseFlow!
    var subscriptionFeatureAvailability: SubscriptionFeatureAvailabilityMock!
    var mockFreemiumDBPExperimentManager: MockFreemiumDBPExperimentManager!
    var feature: SubscriptionPagesUseSubscriptionFeature!
    var pixelsFired: [String] = []
    var uiEventsHappened: [SubscriptionUIHandlerMock.UIHandlerMockPerformedAction] = []

    @MainActor override func setUpWithError() throws {
        // Mocks
        userDefaults = UserDefaults(suiteName: Constants.userDefaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: Constants.userDefaultsSuiteName)

        pixelKit = PixelKit(dryRun: false,
                            appVersion: "1.0.0",
                            defaultHeaders: [:],
                            defaults: userDefaults) { pixelName, _, _, _, _, _ in
            self.pixelsFired.append(pixelName)
        }
        pixelKit.clearFrequencyHistoryForAllPixels()
        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        uiHandler = SubscriptionUIHandlerMock { action in
            self.uiEventsHappened.append(action)
        }
        subscriptionManager = SubscriptionManagerMock()
        subscriptionManager.resultURL = URL(string: "https://example.com")
        storePurchaseManager = StorePurchaseManagerMock()
        subscriptionManager.resultStorePurchaseManager = storePurchaseManager
        subscriptionEnvironment = SubscriptionEnvironment(serviceEnvironment: .staging,
                                                          purchasePlatform: .stripe)
        subscriptionManager.currentEnvironment = subscriptionEnvironment
        appStoreRestoreFlow = DefaultAppStoreRestoreFlow(subscriptionManager: subscriptionManager,
                                                         storePurchaseManager: storePurchaseManager)

        appStorePurchaseFlow = DefaultAppStorePurchaseFlow(subscriptionManager: subscriptionManager,
                                                           storePurchaseManager: storePurchaseManager,
                                                           appStoreRestoreFlow: appStoreRestoreFlow)
        stripePurchaseFlow = DefaultStripePurchaseFlow(subscriptionManager: subscriptionManager)
        subscriptionFeatureAvailability = SubscriptionFeatureAvailabilityMock(isFeatureAvailable: true,
                                                                              isSubscriptionPurchaseAllowed: true,
                                                                              usesUnifiedFeedbackForm: false)
        mockFreemiumDBPExperimentManager = MockFreemiumDBPExperimentManager()

        feature = SubscriptionPagesUseSubscriptionFeature(subscriptionManager: subscriptionManager,
                                                          stripePurchaseFlow: stripePurchaseFlow,
                                                          uiHandler: uiHandler,
                                                          subscriptionFeatureAvailability: subscriptionFeatureAvailability,
                                                          freemiumDBPPixelExperimentManager: mockFreemiumDBPExperimentManager)
        feature.with(broker: broker)
    }

    override func tearDownWithError() throws {
        userDefaults = nil
        pixelsFired.removeAll()
        uiEventsHappened.removeAll()
        storePurchaseManager = nil
        subscriptionEnvironment = nil
        appStorePurchaseFlow = nil
        appStoreRestoreFlow = nil
        stripePurchaseFlow = nil
        subscriptionFeatureAvailability = nil
        subscriptionManager = nil
        feature = nil
    }

    // MARK: - Tests for getSubscriptionOptions

    func testGetSubscriptionOptionsSuccess() async throws {
        // Given
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .stripe)
        subscriptionManager.productsResponse = .success(Constants.productItems)

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult.options, Constants.subscriptionOptions.options)
        XCTAssertEqual(subscriptionOptionsResult.platform, Constants.subscriptionOptions.platform)
        XCTAssertPrivacyPixelsFired([])
    }

    func testGetSubscriptionOptionsReturnsEmptyOptionsWhenNoSubscriptionOptions() async throws {
        // Given
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .stripe)
        subscriptionManager.productsResponse = .success([])
        storePurchaseManager.subscriptionOptionsResult = nil

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult, SubscriptionOptions.empty)
        XCTAssertPrivacyPixelsFired([])
    }

    func testGetSubscriptionOptionsReturnsEmptyOptionsWhenSubscriptionOptionsDidNotFetch() async throws {
        // Given
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .stripe)
        subscriptionManager.productsResponse = .failure(Subscription.SubscriptionManagerError.tokenUnavailable(error: nil))
        storePurchaseManager.subscriptionOptionsResult = nil

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult, SubscriptionOptions.empty)
        XCTAssertPrivacyPixelsFired([])
    }

    // MARK: - Tests for subscriptionSelected

    func testSubscriptionSelectedSuccessWhenPurchasingFirstTime() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .stripe)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)
        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        let subscriptionID = "some-subscription-id"
        subscriptionManager.resultSubscription = SubscriptionMockFactory.subscription
        storePurchaseManager.purchaseSubscriptionResult = .success(subscriptionID)
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)

        // When
        let subscriptionSelectedParams = ["id": subscriptionID]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertEqual(uiEventsHappened, [.didDismissProgressViewController])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c"])
    }

    func testSubscriptionSelectedSuccessWhenRepurchasingForExpiredAppleSubscription() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .stripe)
        XCTAssertTrue(subscriptionManager.isUserAuthenticated)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredSubscription

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
//        XCTAssertFalse(authService.createAccountCalled)
        XCTAssertEqual(uiEventsHappened, [.didDismissProgressViewController])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c"])
    }

    func testSubscriptionSelectedErrorWhenUnauthenticatedAndAccountCreationFails() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .stripe)
        subscriptionManager.resultCreateAccountTokenContainer = nil
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertFalse(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertTrue(uiEventsHappened.count == 4)
        XCTAssertTrue(uiEventsHappened.contains(.didDismissProgressViewController))
        XCTAssertTrue(uiEventsHappened.contains(.didShowAlert(.somethingWentWrong)))
        XCTAssertTrue(uiEventsHappened.contains(.didShowTab(.subscription(subscriptionManager.url(for: .purchase)))))
        XCTAssertTrue(uiEventsHappened.contains(.didDismissProgressViewController))
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureAccountNotCreated.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureAccountNotCreated.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    // MARK: - Tests for completeStripePayment

    func testCompleteStripePaymentSuccess() async throws {
        // Given
        ensureUserAuthenticatedState()

//        authService.getAccessTokenResult = .success(AccessTokenResponse(accessToken: Constants.accessToken))
//        authService.validateTokenResult = .success(Constants.validateTokenResponse)
//        subscriptionManager.resultSubscription = SubscriptionMockFactory.subscription
//        subscriptionManager.resultExchangeTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()

        // When
        let result = try await feature.completeStripePayment(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController])

        let dictionaryResult = try XCTUnwrap(result as? [String: String])
        XCTAssertTrue(dictionaryResult.isEmpty)

        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseStripeSuccess.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseStripeSuccess.name + "_c"])
    }
}

@available(macOS 12.0, *)
extension SubscriptionPagesUseSubscriptionFeatureForStripeTests {

    func ensureUserAuthenticatedState() {
        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
    }

    func ensureUserUnauthenticatedState() {
        subscriptionManager.resultTokenContainer = nil
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