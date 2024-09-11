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
import os.log

@available(macOS 12.0, *)
final class SubscriptionPagesUseSubscriptionFeatureTests: XCTestCase {

    private struct Constants {
        static let userDefaultsSuiteName = "SubscriptionPagesUseSubscriptionFeatureTests"

        static let authToken = UUID().uuidString
        static let accessToken = UUID().uuidString
        static let externalID = UUID().uuidString

        static let email = "dax@duck.com"

        static let entitlements = [Entitlement(product: .dataBrokerProtection),
                                   Entitlement(product: .identityTheftRestoration),
                                   Entitlement(product: .networkProtection)]

        static let mostRecentTransactionJWS = "dGhpcyBpcyBub3QgYSByZWFsIEFw(...)cCBTdG9yZSB0cmFuc2FjdGlvbiBKV1M="

        static let subscriptionOptions = SubscriptionOptions(platform: SubscriptionPlatformName.ios.rawValue,
                                                             options: [
                                                                SubscriptionOption(id: "1",
                                                                                   cost: SubscriptionOptionCost(displayPrice: "9 USD", recurrence: "monthly")),
                                                                SubscriptionOption(id: "2",
                                                                                   cost: SubscriptionOptionCost(displayPrice: "99 USD", recurrence: "yearly"))
                                                             ],
                                                             features: [
                                                                SubscriptionFeature(name: "vpn"),
                                                                SubscriptionFeature(name: "personal-information-removal"),
                                                                SubscriptionFeature(name: "identity-theft-restoration")
                                                             ])

        static let validateTokenResponse = ValidateTokenResponse(account: ValidateTokenResponse.Account(email: Constants.email,
                                                                                                        entitlements: Constants.entitlements,
                                                                                                        externalID: Constants.externalID))

        static let mockParams: [String: String] = [:]
        @MainActor static let mockScriptMessage = MockWKScriptMessage(name: "", body: "", webView: WKWebView() )

        static let invalidTokenError = APIServiceError.serverError(statusCode: 401, error: "invalid_token")
    }

    var userDefaults: UserDefaults!
    var broker: UserScriptMessageBroker = UserScriptMessageBroker(context: "testBroker")
    var uiHandler: SubscriptionUIHandlerMock!

    var accountStorage: AccountKeychainStorageMock!
    var accessTokenStorage: SubscriptionTokenKeychainStorageMock!
    var entitlementsCache: UserDefaultsCache<[Entitlement]>!

    var subscriptionService: SubscriptionEndpointServiceMock!
    var authService: AuthEndpointServiceMock!

    var storePurchaseManager: StorePurchaseManagerMock!
    var subscriptionEnvironment: SubscriptionEnvironment!

    var appStorePurchaseFlow: AppStorePurchaseFlow!
    var appStoreRestoreFlow: AppStoreRestoreFlow!
    var appStoreAccountManagementFlow: AppStoreAccountManagementFlow!
    var stripePurchaseFlow: StripePurchaseFlow!

    var subscriptionFeatureAvailability: SubscriptionFeatureAvailabilityMock!

    var accountManager: AccountManager!
    var subscriptionManager: SubscriptionManager!

    var feature: SubscriptionPagesUseSubscriptionFeature!

    var uiEventsHappened: [SubscriptionUIHandlerMock.UIHandlerMockPerformedAction] = []

    @MainActor override func setUpWithError() throws {
        // Mocks
        userDefaults = UserDefaults(suiteName: Constants.userDefaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: Constants.userDefaultsSuiteName)

        uiHandler = SubscriptionUIHandlerMock() { action in
            self.uiEventsHappened.append(action)
        }

        subscriptionService = SubscriptionEndpointServiceMock()
        authService = AuthEndpointServiceMock()

        storePurchaseManager = StorePurchaseManagerMock()
        subscriptionEnvironment = SubscriptionEnvironment(serviceEnvironment: .production,
                                                           purchasePlatform: .appStore)
        accountStorage = AccountKeychainStorageMock()
        accessTokenStorage = SubscriptionTokenKeychainStorageMock()

        entitlementsCache = UserDefaultsCache<[Entitlement]>(userDefaults: userDefaults,
                                                             key: UserDefaultsCacheKey.subscriptionEntitlements,
                                                             settings: UserDefaultsCacheSettings(defaultExpirationInterval: .minutes(20)))

        // Real AccountManager
        accountManager = DefaultAccountManager(storage: accountStorage,
                                               accessTokenStorage: accessTokenStorage,
                                               entitlementsCache: entitlementsCache,
                                               subscriptionEndpointService: subscriptionService,
                                               authEndpointService: authService)

        // Real Flows
        appStoreRestoreFlow = DefaultAppStoreRestoreFlow(accountManager: accountManager,
                                                         storePurchaseManager: storePurchaseManager,
                                                         subscriptionEndpointService: subscriptionService,
                                                         authEndpointService: authService)

        appStorePurchaseFlow = DefaultAppStorePurchaseFlow(subscriptionEndpointService: subscriptionService,
                                                           storePurchaseManager: storePurchaseManager,
                                                           accountManager: accountManager,
                                                           appStoreRestoreFlow: appStoreRestoreFlow,
                                                           authEndpointService: authService)

        appStoreAccountManagementFlow = DefaultAppStoreAccountManagementFlow(authEndpointService: authService,
                                                                             storePurchaseManager: storePurchaseManager,
                                                                             accountManager: accountManager)

        stripePurchaseFlow = DefaultStripePurchaseFlow(subscriptionEndpointService: subscriptionService,
                                                       authEndpointService: authService,
                                                       accountManager: accountManager)

        subscriptionFeatureAvailability = SubscriptionFeatureAvailabilityMock(isFeatureAvailable: true,
                                                                              isSubscriptionPurchaseAllowed: true,
                                                                              usesUnifiedFeedbackForm: false)

        // Real SubscriptionManager
        subscriptionManager = DefaultSubscriptionManager(storePurchaseManager: storePurchaseManager,
                                                         accountManager: accountManager,
                                                         subscriptionEndpointService: subscriptionService,
                                                         authEndpointService: authService,
                                                         subscriptionEnvironment: subscriptionEnvironment)

        feature = SubscriptionPagesUseSubscriptionFeature(subscriptionManager: subscriptionManager,
                                                          stripePurchaseFlow: stripePurchaseFlow,
                                                          uiHandler: uiHandler,
                                                          subscriptionFeatureAvailability: subscriptionFeatureAvailability)
        feature.with(broker: broker)
    }

    override func tearDownWithError() throws {
        if !uiEventsHappened.isEmpty {
            Logger.general.log("= events =")

            uiEventsHappened.forEach { action in
                Logger.general.log("\(String(describing: action))")
            }

            Logger.general.log("==========")
        }

        userDefaults = nil
        uiEventsHappened.removeAll()

        subscriptionService = nil
        authService = nil
        storePurchaseManager = nil
        subscriptionEnvironment = nil

        accountStorage = nil
        accessTokenStorage = nil

        entitlementsCache.reset()
        entitlementsCache = nil

        accountManager = nil

        // Real Flows
        appStorePurchaseFlow = nil
        appStoreRestoreFlow = nil
        appStoreAccountManagementFlow = nil
        stripePurchaseFlow = nil

        subscriptionFeatureAvailability = nil

        subscriptionManager = nil

        feature = nil
    }

    // MARK: - Tests for getSubscription

    func testGetSubscriptionSuccessWithoutRefreshingAuthToken() async throws {
        // Given
        ensureUserAuthenticatedState()

        authService.validateTokenResult = .success(Constants.validateTokenResponse)

        // When
        let result = try await feature.getSubscription(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscription = try XCTUnwrap(result as? SubscriptionPagesUseSubscriptionFeature.Subscription)
        XCTAssertEqual(subscription.token, Constants.authToken)
        XCTAssertEqual(accountManager.authToken, Constants.authToken)
    }

    func testGetSubscriptionSuccessErrorWhenUnauthenticated() async throws {
        // Given
        ensureUserUnauthenticatedState()

        authService.validateTokenResult = .failure(Constants.invalidTokenError)
        storePurchaseManager.mostRecentTransactionResult = nil

        // When
        let result = try await feature.getSubscription(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscription = try XCTUnwrap(result as? SubscriptionPagesUseSubscriptionFeature.Subscription)
        XCTAssertEqual(subscription.token, "")
        XCTAssertFalse(accountManager.isUserAuthenticated)
    }

    // MARK: - Tests for setSubscription

    func testSetSubscriptionSuccess() async throws {
        // Given
        ensureUserUnauthenticatedState()

        authService.getAccessTokenResult = .success(.init(accessToken: Constants.accessToken))
        authService.validateTokenResult = .success(Constants.validateTokenResponse)

        // When
        let setSubscriptionParams = ["token": Constants.authToken]
        let result = try await feature.setSubscription(params: setSubscriptionParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check pixel fired: PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseEmailSuccess, frequency: .dailyAndCount)
        XCTAssertEqual(accountManager.authToken, Constants.authToken)
        XCTAssertEqual(accountManager.accessToken, Constants.accessToken)
        XCTAssertEqual(accountManager.email, Constants.email)
        XCTAssertEqual(accountManager.externalID, Constants.externalID)
        XCTAssertNil(result)
    }

    func testSetSubscriptionErrorWhenFailedToExchangeToken() async throws {
        // Given
        ensureUserUnauthenticatedState()

        authService.getAccessTokenResult = .failure(Constants.invalidTokenError)

        // When
        let setSubscriptionParams = ["token": Constants.authToken]
        let result = try await feature.setSubscription(params: setSubscriptionParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertNil(accountManager.authToken)
        XCTAssertFalse(accountManager.isUserAuthenticated)
        XCTAssertNil(result)
    }

    func testSetSubscriptionErrorWhenFailedToFetchAccountDetails() async throws {
        // Given
        ensureUserUnauthenticatedState()

        authService.getAccessTokenResult = .success(.init(accessToken: Constants.accessToken))
        authService.validateTokenResult = .failure(Constants.invalidTokenError)

        // When
        let setSubscriptionParams = ["token": Constants.authToken]
        let result = try await feature.setSubscription(params: setSubscriptionParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertNil(accountManager.authToken)
        XCTAssertFalse(accountManager.isUserAuthenticated)
        XCTAssertNil(result)
    }

    // MARK: - Tests for backToSettings

    func testBackToSettingsSuccess() async throws {
        // Given
        ensureUserAuthenticatedState()
        accountStorage.email = nil

        XCTAssertNil(accountManager.email)

        let notificationPostedExpectation = expectation(forNotification: .subscriptionPageCloseAndOpenPreferences, object: nil)

        authService.validateTokenResult = .success(Constants.validateTokenResponse)

        // When
        let result = try await feature.backToSettings(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertEqual(accountManager.email, Constants.email)
        XCTAssertNil(result)
    }

    func testBackToSettingsErrorOnFetchingAccountDetails() async throws {
        // Given
        ensureUserAuthenticatedState()

        let notificationPostedExpectation = expectation(forNotification: .subscriptionPageCloseAndOpenPreferences, object: nil)

        authService.validateTokenResult = .failure(Constants.invalidTokenError)

        // When
        let result = try await feature.backToSettings(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    // MARK: - Tests for getSubscriptionOptions

    func testGetSubscriptionOptionsSuccess() async throws {
        // Given
        storePurchaseManager.subscriptionOptionsResult = Constants.subscriptionOptions

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult, Constants.subscriptionOptions)
    }

    func testGetSubscriptionOptionsReturnsEmptyOptionsWhenNoSubscriptionOptions() async throws {
        // Given
        storePurchaseManager.subscriptionOptionsResult = nil

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult, SubscriptionOptions.empty)
    }

    func testGetSubscriptionOptionsReturnsEmptyOptionsWhenPurchaseNotAllowed() async throws {
        // Given
        subscriptionFeatureAvailability.isSubscriptionPurchaseAllowed = false

        storePurchaseManager.subscriptionOptionsResult = Constants.subscriptionOptions

        // When
        let result = try await feature.getSubscriptionOptions(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let subscriptionOptionsResult = try XCTUnwrap(result as? SubscriptionOptions)
        XCTAssertEqual(subscriptionOptionsResult, SubscriptionOptions.empty)
    }

    // MARK: - Tests for subscriptionSelected

    func testSubscriptionSelectedSuccessWhenPurchasingFirstTime() async throws {
        // Given
        ensureUserUnauthenticatedState()

        XCTAssertEqual(subscriptionEnvironment.purchasePlatform, .appStore)
        XCTAssertFalse(accountManager.isUserAuthenticated)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

        authService.createAccountResult = .success(CreateAccountResponse(authToken: Constants.authToken,
                                                                         externalID: Constants.externalID,
                                                                         status: "created"))
        authService.getAccessTokenResult = .success(AccessTokenResponse(accessToken: Constants.accessToken))
        authService.validateTokenResult = .success(Constants.validateTokenResponse)
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionService.confirmPurchaseResult = .success(ConfirmPurchaseResponse(email: Constants.email,
                                                                                     entitlements: Constants.entitlements,
                                                                                     subscription: SubscriptionMockFactory.subscription))

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check pixel fired: DailyPixel.fireDailyAndCount(pixel: .privacyProPurchaseAttempt)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didUpdateProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertNil(result)
    }

    func testSubscriptionSelectedSuccessWhenRepurchasingForExpiredAppleSubscription() async throws {
        // Given
        ensureUserAuthenticatedState()

        XCTAssertTrue(accountManager.isUserAuthenticated)

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = Constants.mostRecentTransactionJWS
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredSubscription)

        authService.storeLoginResult = .success(StoreLoginResponse(authToken: Constants.authToken,
                                                                   email: Constants.email,
                                                                   externalID: Constants.externalID,
                                                                   id: 1,
                                                                   status: "authenticated"))
        authService.getAccessTokenResult = .success(AccessTokenResponse(accessToken: Constants.accessToken))
        authService.validateTokenResult = .success(Constants.validateTokenResponse)
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionService.confirmPurchaseResult = .success(ConfirmPurchaseResponse(email: Constants.email,
                                                                                     entitlements: Constants.entitlements,
                                                                                     subscription: SubscriptionMockFactory.subscription))

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check pixel fired: DailyPixel.fireDailyAndCount(pixel: .privacyProPurchaseAttempt)
        // DailyPixel.fireDailyAndCount(pixel: .privacyProPurchaseSuccess)
        // UniquePixel.fire(pixel: .privacyProSubscriptionActivated)
        // Pixel.fireAttribution(pixel: .privacyProSuccessfulSubscriptionAttribution, origin: subscriptionAttributionOrigin, privacyProDataReporter: privacyProDataReporter)
        XCTAssertFalse(authService.createAccountCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didUpdateProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertNil(result)
    }

    func testSubscriptionSelectedSuccessWhenRepurchasingForExpiredStripeSubscription() async throws {
        // Given
        ensureUserAuthenticatedState()

        XCTAssertTrue(accountManager.isUserAuthenticated)

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
        storePurchaseManager.purchaseSubscriptionResult = .success(Constants.mostRecentTransactionJWS)
        subscriptionService.confirmPurchaseResult = .success(ConfirmPurchaseResponse(email: Constants.email,
                                                                                     entitlements: Constants.entitlements,
                                                                                     subscription: SubscriptionMockFactory.subscription))

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check pixel fired: DailyPixel.fireDailyAndCount(pixel: .privacyProPurchaseAttempt)
            // DailyPixel.fireDailyAndCount(pixel: .privacyProPurchaseSuccess)
            // UniquePixel.fire(pixel: .privacyProSubscriptionActivated)
            // Pixel.fireAttribution(pixel: .privacyProSuccessfulSubscriptionAttribution, origin: subscriptionAttributionOrigin, privacyProDataReporter: privacyProDataReporter)
        XCTAssertFalse(authService.createAccountCalled)
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didUpdateProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertNil(result)
    }

    func testSubscriptionSelectedErrorWhenPurchasingWhenHavingActiveSubscription() async throws {
        // Given
        ensureUserAuthenticatedState()

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
    }

    func testSubscriptionSelectedErrorWhenPurchasingWhenUnauthenticatedAndHavingActiveSubscriptionOnAppleID() async throws {
        // Given
        ensureUserUnauthenticatedState()

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
    }

    func testSubscriptionSelectedErrorWhenUnauthenticatedAndAccountCreationFails() async throws {
        // Given
        ensureUserUnauthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        storePurchaseManager.mostRecentTransactionResult = nil

        authService.createAccountResult = .failure(Constants.invalidTokenError)
        await uiHandler.setAlertResponse(alertResponse: .alertFirstButtonReturn)

        // When
        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check pixel fired: DailyPixel.fireDailyAndCount(pixel: .privacyProPurchaseAttempt)
        XCTAssertFalse(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController,
                                          .didShowAlert(.somethingWentWrong),
                                          .didShowTab(.subscription(subscriptionManager.url(for: .purchase)))])
        XCTAssertNil(result)
    }

    func testSubscriptionSelectedErrorWhenPurchaseCancelledByUser() async throws {
        // Given
        ensureUserAuthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
        storePurchaseManager.purchaseSubscriptionResult = .failure(StorePurchaseManagerError.purchaseCancelledByUser)

        let subscriptionSelectedParams = ["id": "some-subscription-id"]
        let result = try await feature.subscriptionSelected(params: subscriptionSelectedParams, original: Constants.mockScriptMessage)

        // Then
        XCTAssertTrue(storePurchaseManager.purchaseSubscriptionCalled)
        XCTAssertEqual(uiEventsHappened, [.didPresentProgressViewController,
                                          .didDismissProgressViewController])
        XCTAssertNil(result)
    }

    func testSubscriptionSelectedErrorWhenProductNotFound() async throws {
        // Given
        ensureUserAuthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
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
    }

    func testSubscriptionSelectedErrorWhenExternalIDIsNotValidUUID() async throws {
        // Given
        ensureUserAuthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
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
    }

    func testSubscriptionSelectedErrorWhenPurchaseFailed() async throws {
        // Given
        ensureUserAuthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
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
    }

    func testSubscriptionSelectedErrorWhenTransactionCannotBeVerified() async throws {
        // Given
        ensureUserAuthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
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
    }

    func testSubscriptionSelectedErrorWhenTransactionPendingAuthentication() async throws {
        // Given
        ensureUserAuthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
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
    }

    func testSubscriptionSelectedErrorDueToUnknownPurchaseError() async throws {
        // Given
        ensureUserAuthenticatedState()

        storePurchaseManager.hasActiveSubscriptionResult = false
        subscriptionService.getSubscriptionResult = .success(SubscriptionMockFactory.expiredStripeSubscription)
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
        // TODO: Check pixel fired: PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseOfferPageEntry)
        await fulfillment(of: [uiHandlerCalledExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    // MARK: - Tests for featureSelected

    func testFeatureSelectedSuccessForPrivateBrowsing() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionFeatureName.privateBrowsing

        let notificationPostedExpectation = expectation(forNotification: .openPrivateBrowsing, object: nil)

        // When
        let featureSelectionParams = ["feature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    func testFeatureSelectedSuccessForPrivateSearch() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionFeatureName.privateSearch

        let notificationPostedExpectation = expectation(forNotification: .openPrivateSearch, object: nil)

        // When
        let featureSelectionParams = ["feature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    func testFeatureSelectedSuccessForEmailProtection() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionFeatureName.emailProtection

        let notificationPostedExpectation = expectation(forNotification: .openEmailProtection, object: nil)

        // When
        let featureSelectionParams = ["feature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    func testFeatureSelectedSuccessForAppTrackingProtection() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionFeatureName.appTrackingProtection

        let notificationPostedExpectation = expectation(forNotification: .openAppTrackingProtection, object: nil)

        // When
        let featureSelectionParams = ["feature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    func testFeatureSelectedSuccessForNetworkProtection() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionFeatureName.vpn

        let notificationPostedExpectation = expectation(forNotification: .ToggleNetworkProtectionInMainWindow, object: nil)

        // When
        let featureSelectionParams = ["feature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check for pixel being sent -> PixelKit.fire(PrivacyProPixel.privacyProWelcomeVPN, frequency: .unique)
        await fulfillment(of: [notificationPostedExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    func testFeatureSelectedSuccessForPersonalInformationRemoval() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionFeatureName.personalInformationRemoval

        let notificationPostedExpectation = expectation(forNotification: .openPersonalInformationRemoval, object: nil)
        let uiHandlerCalledExpectation = expectation(description: "uiHandlerCalled")

        await uiHandler.setDidPerformActionCallback { action in
            if action == .didShowTab(.dataBrokerProtection) {
                uiHandlerCalledExpectation.fulfill()
            }
        }

        // When
        let featureSelectionParams = ["feature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check for pixel being sent -> PixelKit.fire(PrivacyProPixel.privacyProWelcomePersonalInformationRemoval, frequency: .unique)
        await fulfillment(of: [notificationPostedExpectation, uiHandlerCalledExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    func testFeatureSelectedSuccessForIdentityTheftRestoration() async throws {
        // Given
        ensureUserAuthenticatedState()
        let selectedFeature = SubscriptionFeatureName.identityTheftRestoration

        let uiHandlerCalledExpectation = expectation(description: "uiHandlerCalled")

        await uiHandler.setDidPerformActionCallback { action in
            if case let .didShowTab(.identityTheftRestoration(url)) = action {
                if url == self.subscriptionManager.url(for: .identityTheftRestoration) {
                    uiHandlerCalledExpectation.fulfill()
                }
            }
        }

        // When
        let featureSelectionParams = ["feature": selectedFeature.rawValue]
        let result = try await feature.featureSelected(params: featureSelectionParams, original: Constants.mockScriptMessage)

        // Then
        // TODO: Check for pixel being sent -> PixelKit.fire(PrivacyProPixel.privacyProWelcomeIdentityRestoration, frequency: .unique)
        await fulfillment(of: [uiHandlerCalledExpectation], timeout: 0.5)
        XCTAssertNil(result)
    }

    // MARK: - Tests for getAccessToken

    func testGetAccessTokenSuccess() async throws {
        // Given
        ensureUserAuthenticatedState()

        // When
        let result = try await feature.getAccessToken(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let tokenResponse = try XCTUnwrap(result as? [String: String])
        XCTAssertEqual(tokenResponse["token"], Constants.accessToken)
    }

    func testGetAccessTokenEmptyOnMissingToken() async throws {
        // Given
        ensureUserUnauthenticatedState()
        XCTAssertNil(accountManager.accessToken)

        // When
        let result = try await feature.getAccessToken(params: Constants.mockParams, original: Constants.mockScriptMessage)

        // Then
        let tokenResponse = try XCTUnwrap(result as? [String: String])
        XCTAssertTrue(tokenResponse.isEmpty)
    }
}

@available(macOS 12.0, *)
extension SubscriptionPagesUseSubscriptionFeatureTests {

    func ensureUserAuthenticatedState() {
        accountStorage.authToken = Constants.authToken
        accountStorage.email = Constants.email
        accountStorage.externalID = Constants.externalID
        accessTokenStorage.accessToken = Constants.accessToken
    }

    func ensureUserUnauthenticatedState() {
        try? accessTokenStorage.removeAccessToken()
        try? accountStorage.clearAuthenticationState()
    }
}
