//
//  SubscriptionPagesUseSubscriptionFeatureTests.swift
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
import DataBrokerProtection
import Networking
import TestUtils

@available(macOS 12.0, *)
final class SubscriptionPagesUseSubscriptionFeatureTests: XCTestCase {

    private struct Constants {
        static let userDefaultsSuiteName = "SubscriptionPagesUseSubscriptionFeatureTests"
        static let externalID = UUID().uuidString
        static let email = "dax@duck.com"
        static let entitlements: [SubscriptionEntitlement] = [.dataBrokerProtection,
                                                            .identityTheftRestoration,
                                                            .networkProtection]

        static let mostRecentTransactionJWS = "dGhpcyBpcyBub3QgYSByZWFsIEFw(...)cCBTdG9yZSB0cmFuc2FjdGlvbiBKV1M="
        static let subscriptionOptions = SubscriptionOptions(
            platform: SubscriptionPlatformName.macos,
            options: [
                SubscriptionOption(id: "1", cost: SubscriptionOptionCost(displayPrice: "9 USD", recurrence: "monthly")),
                SubscriptionOption(id: "2", cost: SubscriptionOptionCost(displayPrice: "99 USD", recurrence: "yearly"))
            ],
            availableEntitlements: [.networkProtection, .dataBrokerProtection, .identityTheftRestoration])
        static let mockParams: [String: String] = [:]
        @MainActor static let mockScriptMessage = MockWKScriptMessage(name: "", body: "", webView: WKWebView() )
    }

    var userDefaults: UserDefaults!
    var broker: UserScriptMessageBroker = UserScriptMessageBroker(context: "testBroker")
    var uiHandler: SubscriptionUIHandlerMock!
    var pixelKit: PixelKit!
    var storePurchaseManager: StorePurchaseManagerMock!
    var subscriptionEnvironment: SubscriptionEnvironment!
    var appStorePurchaseFlow: AppStorePurchaseFlow!
    var appStoreRestoreFlow: AppStoreRestoreFlow!
    var stripePurchaseFlow: StripePurchaseFlow!
    var subscriptionAttributionPixelHandler: SubscriptionAttributionPixelHandler!
    var subscriptionFeatureAvailability: SubscriptionFeatureAvailabilityMock!
    var subscriptionManager: SubscriptionManagerMock!
    var mockFreemiumDBPExperimentManager: MockFreemiumDBPExperimentManager!
    private var mockPixelHandler: MockFreemiumDBPExperimentPixelHandler!
    private var mockFreemiumDBPUserStateManager: MockFreemiumDBPUserStateManager!
    var pixelsFired: [String] = []
    var uiEventsHappened: [SubscriptionUIHandlerMock.UIHandlerMockPerformedAction] = []

    var feature: SubscriptionPagesUseSubscriptionFeature!

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

        storePurchaseManager = StorePurchaseManagerMock()
        subscriptionEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .appStore)
        subscriptionManager = SubscriptionManagerMock()
        subscriptionManager.resultStorePurchaseManager = storePurchaseManager
        subscriptionManager.resultURL = URL(string: "https://example.com")
        subscriptionManager.currentEnvironment = subscriptionEnvironment
        appStoreRestoreFlow = DefaultAppStoreRestoreFlow(subscriptionManager: subscriptionManager,
                                                         storePurchaseManager: storePurchaseManager)
        appStorePurchaseFlow = DefaultAppStorePurchaseFlow(subscriptionManager: subscriptionManager,
                                                           storePurchaseManager: storePurchaseManager,
                                                           appStoreRestoreFlow: appStoreRestoreFlow)
        stripePurchaseFlow = DefaultStripePurchaseFlow(subscriptionManager: subscriptionManager)
        subscriptionAttributionPixelHandler = PrivacyProSubscriptionAttributionPixelHandler()
        subscriptionFeatureAvailability = SubscriptionFeatureAvailabilityMock(isFeatureAvailable: true,
                                                                              isSubscriptionPurchaseAllowed: true,
                                                                              usesUnifiedFeedbackForm: false)
        mockFreemiumDBPExperimentManager = MockFreemiumDBPExperimentManager()
        mockPixelHandler = MockFreemiumDBPExperimentPixelHandler()
        mockFreemiumDBPUserStateManager = MockFreemiumDBPUserStateManager()
        feature = SubscriptionPagesUseSubscriptionFeature(subscriptionManager: subscriptionManager,
                                                          subscriptionSuccessPixelHandler: subscriptionAttributionPixelHandler,
                                                          stripePurchaseFlow: stripePurchaseFlow,
                                                          uiHandler: uiHandler,
                                                          subscriptionFeatureAvailability: subscriptionFeatureAvailability,
                                                          freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
                                                          freemiumDBPPixelExperimentManager: mockFreemiumDBPExperimentManager,
                                                          freemiumDBPExperimentPixelHandler: mockPixelHandler)
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

    // MARK: - Tests for getSubscription

    func testGetSubscriptionSuccessWithoutRefreshingAuthToken() async throws {
        // Given
        ensureUserAuthenticatedState()
        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()

        // When
        let result = try await feature.getSubscription(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscription = try XCTUnwrap(result as? SubscriptionPagesUseSubscriptionFeature.Subscription)
        XCTAssertEqual(subscription.token, subscriptionManager.resultTokenContainer?.accessToken)
        XCTAssertPrivacyPixelsFired([])
    }

    func testGetSubscriptionSuccessErrorWhenUnauthenticated() async throws {
        // Given
        ensureUserUnauthenticatedState()

        subscriptionManager.resultTokenContainer = nil
        storePurchaseManager.mostRecentTransactionResult = nil

        // When
        let result = try await feature.getSubscription(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscription = try XCTUnwrap(result as? SubscriptionPagesUseSubscriptionFeature.Subscription)
        XCTAssertEqual(subscription.token, "")
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)
        XCTAssertPrivacyPixelsFired([])
    }

    // MARK: - Tests for setSubscription

    func testSetSubscriptionSuccess() async throws {
        // Given
        ensureUserUnauthenticatedState()
        subscriptionManager.resultExchangeTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()

        // When
        let setSubscriptionParams = ["token": subscriptionManager.resultExchangeTokenContainer!.accessToken]
        let result = try await feature.setSubscription(params: setSubscriptionParams, original: Constants.mockScriptMessage)

        // Then
        let tokens = try await subscriptionManager.getTokenContainer(policy: .local)
        XCTAssertEqual(tokens, subscriptionManager.resultExchangeTokenContainer)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProRestorePurchaseEmailSuccess.name + "_d",
                                     PrivacyProPixel.privacyProRestorePurchaseEmailSuccess.name + "_c"])
    }

    func testSetSubscriptionErrorWhenFailedToExchangeToken() async throws {
        // Given
        ensureUserUnauthenticatedState()
        subscriptionManager.resultExchangeTokenContainer = nil

        // When
        let setSubscriptionParams = ["token": "sometoken"]
        let result = try await feature.setSubscription(params: setSubscriptionParams, original: Constants.mockScriptMessage)

        // Then
        let tokens = try? await subscriptionManager.getTokenContainer(policy: .local)
        XCTAssertNil(tokens)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProRestorePurchaseEmailSuccess.name + "_d",
                                     PrivacyProPixel.privacyProRestorePurchaseEmailSuccess.name + "_c"])
    }

    // MARK: - Tests for backToSettings

    func testBackToSettingsSuccess() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertNil(subscriptionManager.userEmail)

        let notificationPostedExpectation = expectation(forNotification: .subscriptionPageCloseAndOpenPreferences, object: nil)

        // When
        let result = try await feature.backToSettings(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 1)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([])
    }

    func testBackToSettingsErrorOnFetchingAccountDetails() async throws {
        // Given
        ensureUserUnauthenticatedState()

        let notificationPostedExpectation = expectation(forNotification: .subscriptionPageCloseAndOpenPreferences, object: nil)

        // When
        let result = try await feature.backToSettings(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 1)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([])
    }

    // MARK: - Tests for getSubscriptionOptions

    func testGetSubscriptionOptionsSuccess() async throws {
        // Given
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        storePurchaseManager.subscriptionOptionsResult = Constants.subscriptionOptions

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult, Constants.subscriptionOptions)
        XCTAssertPrivacyPixelsFired([])
    }

    func testGetSubscriptionOptionsReturnsEmptyOptionsWhenNoSubscriptionOptions() async throws {
        // Given
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        storePurchaseManager.subscriptionOptionsResult = nil

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult, SubscriptionOptions.empty)
        XCTAssertPrivacyPixelsFired([])
    }

    func testGetSubscriptionOptionsReturnsEmptyOptionsWhenPurchaseNotAllowed() async throws {
        // Given
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        subscriptionFeatureAvailability.isSubscriptionPurchaseAllowed = false

        storePurchaseManager.subscriptionOptionsResult = Constants.subscriptionOptions

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
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didUpdateProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_c",
                                     PrivacyProPixel.privacyProSubscriptionActivated.name])
    }

    func testSubscriptionSelectedSuccessWhenPurchasingFirstTimeAndUserIsFreemium() async throws {
        // Given
        mockFreemiumDBPUserStateManager.didActivate = true
        mockFreemiumDBPExperimentManager.pixelParameters = ["daysEnrolled": "1"]
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        subscriptionManager.resultSubscription = SubscriptionMockFactory.subscription
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didUpdateProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_c",
                                     PrivacyProPixel.privacyProSubscriptionActivated.name])
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.subscription)
        XCTAssertEqual(mockPixelHandler.lastPassedParameters?["daysEnrolled"], "1")
    }

    func testSubscriptionSelectedSuccessWhenRepurchasingForExpiredAppleSubscription() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = Constants.mostRecentTransactionJWS
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredSubscription
        let newSub = SubscriptionMockFactory.subscription
        subscriptionManager.confirmPurchaseResponse = .success(newSub)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
//        XCTAssertFalse(authService.createAccountCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didUpdateProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_c",
                                     PrivacyProPixel.privacyProSubscriptionActivated.name])
    }

    func testSubscriptionSelectedSuccessWhenRepurchasingForExpiredStripeSubscription() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)
        storePurchaseManager.hasActiveSubscriptionResult = false
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredSubscription
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)
        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didUpdateProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseSuccess.name + "_c",
                                     PrivacyProPixel.privacyProSubscriptionActivated.name])
    }

    func testSubscriptionSelectedErrorWhenPurchasingWhenHavingActiveSubscription() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = true
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertFalse(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.subscriptionFound)])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProRestoreAfterPurchaseAttempt.name,
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_c"])
    }

    func testSubscriptionSelectedErrorWhenPurchasingWhenUnauthenticatedAndHavingActiveSubscriptionOnAppleID() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = true
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)
        storePurchaseManager.mostRecentTransactionResult = Constants.mostRecentTransactionJWS
        subscriptionManager.resultSubscription = SubscriptionMockFactory.subscription

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertFalse(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.subscriptionFound)])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProRestoreAfterPurchaseAttempt.name,
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureBackendError.name + "_c",
                                     PrivacyProPixel.privacyProRestorePurchaseStoreSuccess.name + "_d",
                                     PrivacyProPixel.privacyProRestorePurchaseStoreSuccess.name + "_c"])
    }

    func testSubscriptionSelectedErrorWhenUnauthenticatedAndAccountCreationFails() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

//        authService.createAccountResult = .failure(Constants.invalidTokenError)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertFalse(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureAccountNotCreated.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureAccountNotCreated.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    func testSubscriptionSelectedErrorWhenPurchaseCancelledByUser() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredStripeSubscription
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.purchaseCancelledByUser)

        await uiHandler.setAlertResponse(alertResponse: .abort)

        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c"])
    }

    func testSubscriptionSelectedErrorWhenProductNotFound() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredStripeSubscription
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.productNotFound)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    func testSubscriptionSelectedErrorWhenExternalIDIsNotValidUUID() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredStripeSubscription
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.externalIDisNotAValidUUID)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    func testSubscriptionSelectedErrorWhenPurchaseFailed() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredStripeSubscription
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.purchaseFailed)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    func testSubscriptionSelectedErrorWhenTransactionCannotBeVerified() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredStripeSubscription
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.transactionCannotBeVerified)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    func testSubscriptionSelectedErrorWhenTransactionPendingAuthentication() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredStripeSubscription
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.transactionPendingAuthentication)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    func testSubscriptionSelectedErrorDueToUnknownPurchaseError() async throws {
        // Given
        ensureUserAuthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionManager.resultSubscription = SubscriptionMockFactory.expiredStripeSubscription
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.unknownError)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProPurchaseAttempt.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseAttempt.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailureStoreError.name + "_c",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_d",
                                     PrivacyProPixel.privacyProPurchaseFailure.name + "_c",
                                     PrivacyProPixel.privacyProOfferScreenImpression.name])
    }

    // MARK: - Tests for activateSubscription

    func testActivateSubscriptionTokenSuccess() async throws {
        // Given
        ensureUserAuthenticatedState()

        let uiHandlerCalledExpectation = expectation(description: "onActivateSubscription")
        await uiHandler.setDidPerformActionCallback { action in
            if action == .didPresentSubscriptionAccessViewController {
                uiHandlerCalledExpectation.fulfill()
            }
        }

        // When
        let result = try await feature.activateSubscription(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [uiHandlerCalledExpectation], timeout: 0.5)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProRestorePurchaseOfferPageEntry.name])
    }

    // MARK: - Tests for featureSelected

    func testFeatureSelectedSuccessForNetworkProtection() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionEntitlement.networkProtection

        let notificationPostedExpectation = expectation(forNotification: .ToggleNetworkProtectionInMainWindow, object: nil)

        // When
        let featureSelectionParams = ["productFeature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProWelcomeVPN.name])
    }

    func testFeatureSelectedSuccessForPersonalInformationRemoval() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionEntitlement.dataBrokerProtection

        let notificationPostedExpectation = expectation(forNotification: .openPersonalInformationRemoval, object: nil)
        let uiHandlerCalledExpectation = expectation(description: "uiHandlerCalled")

        await uiHandler.setDidPerformActionCallback { action in
            if action == .didShowTab(.dataBrokerProtection) {
                uiHandlerCalledExpectation.fulfill()
            }
        }

        // When
        let featureSelectionParams = ["productFeature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation, uiHandlerCalledExpectation], timeout: 0.5)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProWelcomePersonalInformationRemoval.name])
    }

    func testFeatureSelectedSuccessForIdentityTheftRestoration() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionEntitlement.identityTheftRestoration

        let uiHandlerCalledExpectation = expectation(description: "uiHandlerCalled")

        await uiHandler.setDidPerformActionCallback { action in
            if case let .didShowTab(.identityTheftRestoration(url)) = action {
                if url == self.subscriptionManager.url(for: .identityTheftRestoration) {
                    uiHandlerCalledExpectation.fulfill()
                }
            }
        }

        // When
        let featureSelectionParams = ["productFeature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [uiHandlerCalledExpectation], timeout: 0.5)
        XCTAssertNil(result)
        XCTAssertPrivacyPixelsFired([PrivacyProPixel.privacyProWelcomeIdentityRestoration.name])
    }

    // MARK: - Tests for getAccessToken

    func testGetAccessTokenSuccess() async throws {
        // Given
        ensureUserAuthenticatedState()

        // When
        let result = try await feature.getAccessToken(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let tokenResponse = try XCTUnwrap(result as? [String: String])
        XCTAssertEqual(tokenResponse["token"], subscriptionManager.resultTokenContainer!.accessToken)
        XCTAssertPrivacyPixelsFired([])
    }

    func testGetAccessTokenEmptyOnMissingToken() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)

        // When
        let result = try await feature.getAccessToken(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let tokenResponse = try XCTUnwrap(result as? [String: String])
        XCTAssertTrue(tokenResponse.isEmpty)
        XCTAssertPrivacyPixelsFired([])
    }

    func testSubscriptionUpgradeNotificationSentWhenSubscriptionSelectedSuccessFromFreemium() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)

        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)
        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)

        mockFreemiumDBPUserStateManager.didActivate = true
        feature.with(broker: broker)
        let notificationPostedExpectation = expectation(forNotification: .subscriptionUpgradeFromFreemium, object: nil)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        await fulfillment(of: [notificationPostedExpectation], timeout: 1)

        // Then
        XCTAssertNil(result)
    }

    func testSubscriptionUpgradeNotificationNotSentWhenSubscriptionSelectedSuccessNotFromFreemium() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)

        mockFreemiumDBPUserStateManager.didActivate = false
        feature.with(broker: broker)
        let notificationPostedExpectation = expectation(forNotification: .subscriptionUpgradeFromFreemium, object: nil)
        notificationPostedExpectation.isInverted = true

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        await fulfillment(of: [notificationPostedExpectation], timeout: 1)

        // Then
        XCTAssertNil(result)
    }

    func testFreemiumPixelOriginSetWhenSubscriptionSelectedSuccessFromFreemium() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        subscriptionManager.resultCreateAccountTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)

        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)

        mockFreemiumDBPUserStateManager.didPostFirstProfileSavedNotification = true
        feature.with(broker: broker)
        let freeiumOrigin = PrivacyProSubscriptionAttributionPixelHandler.Consts.freemiumOrigin

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertNil(result)
        XCTAssertEqual(subscriptionAttributionPixelHandler.origin, freeiumOrigin)
    }

    func testFreemiumPixelOriginNotSetWhenSubscriptionSelectedSuccessNotFromFreemium() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)

        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)
        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionManager.confirmPurchaseResponse = .success(SubscriptionMockFactory.subscription)

        mockFreemiumDBPUserStateManager.didPostFirstProfileSavedNotification = false
        feature.with(broker: broker)
        let freeiumOrigin = PrivacyProSubscriptionAttributionPixelHandler.Consts.freemiumOrigin

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertNil(result)
        XCTAssertNotEqual(subscriptionAttributionPixelHandler.origin, freeiumOrigin)
    }
}

@available(macOS 12.0, *)
extension SubscriptionPagesUseSubscriptionFeatureTests {

    func ensureUserAuthenticatedState() {
        subscriptionManager.resultTokenContainer = OAuthTokensFactory.makeValidTokenContainerWithEntitlements()
        XCTAssertTrue(subscriptionManager.isUserAuthenticated)
    }

    func ensureUserUnauthenticatedState() {
        subscriptionManager.resultTokenContainer = nil
        XCTAssertFalse(subscriptionManager.isUserAuthenticated)
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
