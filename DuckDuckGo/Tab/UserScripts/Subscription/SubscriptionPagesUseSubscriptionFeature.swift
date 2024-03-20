//
//  SubscriptionPagesUseSubscriptionFeature.swift
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

#if SUBSCRIPTION

import BrowserServicesKit
import Common
import Combine
import Foundation
import Navigation
import WebKit
import UserScript
import Subscription
import SubscriptionUI

public extension Notification.Name {
    static let subscriptionPageCloseAndOpenPreferences = Notification.Name("com.duckduckgo.subscriptionPage.CloseAndOpenPreferences")
}

final class SubscriptionPagesUseSubscriptionFeature: Subfeature {

    // MARK: - Dependencies
    private var uiHandler: SubscriptionUIHandler
    private var subscriptionManager: SubscriptionManaging// = NSApp.delegateTyped.subscriptionManager
    private var tokenStorage: SubscriptionTokenStorage { subscriptionManager.tokenStorage }
    private var accountManager: AccountManaging // = NSApp.delegateTyped.subscriptionManager.accountManager

    // MARK: Flows
    private var stripePurchaseFlow: StripePurchaseFlow { subscriptionManager.flowProvider.stripePurchaseFlow }
    @available(macOS 12.0, iOS 15.0, *)
    private var appStorePurchaseFlow: AppStorePurchaseFlow { subscriptionManager.flowProvider.appStorePurchaseFlow }
    @available(macOS 12.0, iOS 15.0, *)
    private var appStoreRestoreFlow: AppStoreRestoreFlow { subscriptionManager.flowProvider.appStoreRestoreFlow }

    internal init(uiHandler: SubscriptionUIHandler, subscriptionManager: any SubscriptionManaging, accountManager: any AccountManaging) {
        self.uiHandler = uiHandler
        self.subscriptionManager = subscriptionManager
        self.accountManager = accountManager
    }

    // MARK: - Subfeature

    struct Handlers {
        static let getSubscription = "getSubscription"
        static let setSubscription = "setSubscription"
        static let backToSettings = "backToSettings"
        static let getSubscriptionOptions = "getSubscriptionOptions"
        static let subscriptionSelected = "subscriptionSelected"
        static let activateSubscription = "activateSubscription"
        static let featureSelected = "featureSelected"
        static let completeStripePayment = "completeStripePayment"
        // Pixels related events
        static let subscriptionsMonthlyPriceClicked = "subscriptionsMonthlyPriceClicked"
        static let subscriptionsYearlyPriceClicked = "subscriptionsYearlyPriceClicked"
        static let subscriptionsUnknownPriceClicked = "subscriptionsUnknownPriceClicked"
        static let subscriptionsAddEmailSuccess = "subscriptionsAddEmailSuccess"
        static let subscriptionsWelcomeFaqClicked = "subscriptionsWelcomeFaqClicked"
    }

    // swiftlint:disable:next cyclomatic_complexity
    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch methodName {
        case Handlers.getSubscription: return getSubscription
        case Handlers.setSubscription: return setSubscription
        case Handlers.backToSettings: return backToSettings
        case Handlers.getSubscriptionOptions: return getSubscriptionOptions
        case Handlers.subscriptionSelected: return subscriptionSelected
        case Handlers.activateSubscription: return activateSubscription
        case Handlers.featureSelected: return featureSelected
        case Handlers.completeStripePayment: return completeStripePayment
            // Pixel related events
        case Handlers.subscriptionsMonthlyPriceClicked: return subscriptionsMonthlyPriceClicked
        case Handlers.subscriptionsYearlyPriceClicked: return subscriptionsYearlyPriceClicked
        case Handlers.subscriptionsUnknownPriceClicked: return subscriptionsUnknownPriceClicked
        case Handlers.subscriptionsAddEmailSuccess: return subscriptionsAddEmailSuccess
        case Handlers.subscriptionsWelcomeFaqClicked: return subscriptionsWelcomeFaqClicked
        default:
            return nil
        }
    }

    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [
        .exact(hostname: "duckduckgo.com"),
        .exact(hostname: "abrown.duckduckgo.com")
    ])
    var broker: UserScriptMessageBroker?
    var featureName = "useSubscription"

    func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: -

    struct Subscription: Encodable {
        let token: String
    }

    /// Values that the Frontend can use to determine the current state.
    struct SubscriptionValues: Codable {
        enum CodingKeys: String, CodingKey {
            case token
        }
        let token: String
    }

    func getSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if let authToken = tokenStorage.authToken, tokenStorage.accessToken != nil {
            return Subscription(token: authToken)
        } else {
            return Subscription(token: "")
        }
    }

    func setSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {

        DailyPixel.fire(pixel: .privacyProRestorePurchaseEmailSuccess, frequency: .dailyAndCount)

        guard let subscriptionValues: SubscriptionValues = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionValues")
            return nil
        }

        let authToken = subscriptionValues.token
        if case let .success(accessToken) = await accountManager.exchangeAuthTokenToAccessToken(authToken),
           case let .success(accountDetails) = await accountManager.fetchAccountDetails(with: accessToken) {
            tokenStorage.authToken = authToken
            tokenStorage.accessToken = accessToken
            accountManager.storeAccount(token: accessToken, email: accountDetails.email, externalID: accountDetails.externalID)
        }

        return nil
    }

    func backToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if let accessToken = tokenStorage.accessToken,
           case let .success(accountDetails) = await accountManager.fetchAccountDetails(with: accessToken) {
            accountManager.storeAccount(token: accessToken, email: accountDetails.email, externalID: accountDetails.externalID)
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .subscriptionPageCloseAndOpenPreferences, object: self)
        }

        return nil
    }

    func getSubscriptionOptions(params: Any, original: WKScriptMessage) async throws -> Encodable? {

        if subscriptionManager.configuration.currentPurchasePlatform == .appStore {
            if #available(macOS 12.0, *) {
                switch await appStorePurchaseFlow.subscriptionOptions() {
                case .success(let subscriptionOptions):
                    return subscriptionOptions
                case .failure:
                    break
                }
            }
        } else if subscriptionManager.configuration.currentPurchasePlatform == .stripe {
            switch await stripePurchaseFlow.subscriptionOptions() {
            case .success(let subscriptionOptions):
                return subscriptionOptions
            case .failure:
                break
            }
        }

        return nil
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func subscriptionSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {

        DailyPixel.fire(pixel: .privacyProPurchaseAttempt, frequency: .dailyAndCount)

        struct SubscriptionSelection: Decodable {
            let id: String
        }

        let message = original

        if subscriptionManager.configuration.currentPurchasePlatform == .appStore {

            if #available(macOS 12.0, *) {
                guard let subscriptionSelection: SubscriptionSelection = DecodableHelper.decode(from: params) else {
                    assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionSelection")
                    report(subscriptionActivationError: .generalError)
                    return nil
                }

                os_log(.info, log: .subscription, "[Purchase] Starting purchase for: %{public}s", subscriptionSelection.id)

                let progressViewController = uiHandler.presentProgressViewController(configuration: .purchasing)
                defer { uiHandler.dismiss(viewController: progressViewController) }

                // Check for active subscriptions
                if await PurchaseManager.hasActiveSubscription() {

                    Pixel.fire(.privacyProRestoreAfterPurchaseAttempt)

                    os_log(.info, log: .subscription, "[Purchase] Found active subscription during purchase")
                    report(subscriptionActivationError: .hasActiveSubscription)
                    uiHandler.showSubscriptionFoundAlert(originalMessage: message)
                    return nil
                }

                let emailAccessToken = try? EmailManager().getToken()
                let purchaseTransactionJWS: String

                os_log(.info, log: .subscription, "[Purchase] Purchasing")
                switch await appStorePurchaseFlow.purchaseSubscription(with: subscriptionSelection.id, emailAccessToken: emailAccessToken) {
                case .success(let transactionJWS):
                    purchaseTransactionJWS = transactionJWS
                case .failure(let error):
                    switch error {
                    case .noProductsFound:
                        report(subscriptionActivationError: .subscriptionNotFound)
                    case .activeSubscriptionAlreadyPresent:
                        report(subscriptionActivationError: .activeSubscriptionAlreadyPresent)
                    case .authenticatingWithTransactionFailed:
                        report(subscriptionActivationError: .generalError)
                    case .accountCreationFailed:
                        report(subscriptionActivationError: .accountCreationFailed)
                    case .purchaseFailed:
                        report(subscriptionActivationError: .purchaseFailed)
                    case .cancelledByUser:
                        report(subscriptionActivationError: .cancelledByUser)
                    case .missingEntitlements:
                        report(subscriptionActivationError: .missingEntitlements)
                    }

                    if error != .cancelledByUser {
                        uiHandler.showSomethingWentWrongAlert()
                    }
                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
                    return nil
                }

//                await progressViewController.updateTitleText(UserText.completingPurchaseTitle)
                uiHandler.update(progressViewController: progressViewController, title: UserText.completingPurchaseTitle)

                os_log(.info, log: .subscription, "[Purchase] Completing purchase")

                switch await appStorePurchaseFlow.completeSubscriptionPurchase(with: purchaseTransactionJWS) {
                case .success(let purchaseUpdate):
                    os_log(.info, log: .subscription, "[Purchase] Purchase complete")
                    DailyPixel.fire(pixel: .privacyProPurchaseSuccess, frequency: .dailyAndCount)
                    Pixel.fire(.privacyProSubscriptionActivated, limitTo: .initial)
                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: purchaseUpdate)
                case .failure(let error):
                    switch error {
                    case .noProductsFound:
                        report(subscriptionActivationError: .subscriptionNotFound)
                    case .activeSubscriptionAlreadyPresent:
                        report(subscriptionActivationError: .activeSubscriptionAlreadyPresent)
                    case .authenticatingWithTransactionFailed:
                        report(subscriptionActivationError: .generalError)
                    case .accountCreationFailed:
                        report(subscriptionActivationError: .accountCreationFailed)
                    case .purchaseFailed:
                        report(subscriptionActivationError: .purchaseFailed)
                    case .cancelledByUser:
                        report(subscriptionActivationError: .cancelledByUser)
                    case .missingEntitlements:
                        report(subscriptionActivationError: .missingEntitlements)
                    }

                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
                }
            }
        } else if subscriptionManager.configuration.currentPurchasePlatform == .stripe {
            let emailAccessToken = try? EmailManager().getToken()

            let result = await stripePurchaseFlow.prepareSubscriptionPurchase(emailAccessToken: emailAccessToken)

            switch result {
            case .success(let success):
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: success)
            case .failure(let error):
                uiHandler.showSomethingWentWrongAlert()

                switch error {
                case .noProductsFound:
                    report(subscriptionActivationError: .subscriptionNotFound)
                case .accountCreationFailed:
                    report(subscriptionActivationError: .accountCreationFailed)
                }
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
            }
        }

        return nil
    }

    func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {

        Pixel.fire(.privacyProRestorePurchaseOfferPageEntry)

        let message = original

        Task { @MainActor in

            let actionHandlers = SubscriptionAccessActionHandlers(
                restorePurchases: {

                    if #available(macOS 12.0, *) {
                        self.startAppStoreRestoreFlow { result in

                            switch result {
                            case .success:
                                DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreSuccess, frequency: .dailyAndCount)

                            case .failure(let error):
                                switch error {
                                case .missingAccountOrTransactions: break
                                default:
                                    DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreFailureOther, frequency: .dailyAndCount)
                                }

                                switch error {
                                case .missingAccountOrTransactions:
                                    self.report(subscriptionActivationError: .subscriptionNotFound)
                                    self.uiHandler.showSubscriptionNotFoundAlert()
                                case .subscriptionExpired:
                                    self.report(subscriptionActivationError: .subscriptionExpired)
                                    self.uiHandler.showSubscriptionInactiveAlert()
                                case .pastTransactionAuthenticationError, .failedToObtainAccessToken, .failedToFetchAccountDetails, .failedToFetchSubscriptionDetails:
                                    self.report(subscriptionActivationError: .generalError)
                                    self.uiHandler.showSomethingWentWrongAlert()
                                }
                            }
                            message.webView?.reload()
                        }
                    }
                },
                openURLHandler: { url in
                    self.uiHandler.showSubscriptionTab(withURL: url)
                }, uiActionHandler: { event in
                    switch event {
                    case .activateAddEmailClick:
                        DailyPixel.fire(pixel: .privacyProRestorePurchaseEmailStart, frequency: .dailyAndCount)
                    default:
                        break
                    }
                })

            uiHandler.presentSubscriptionAccessViewController(accountManager: accountManager, actionHandlers: actionHandlers)
        }

        return nil
    }

    func featureSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        struct FeatureSelection: Codable {
            let feature: String
        }

        guard let featureSelection: FeatureSelection = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of FeatureSelection")
            return nil
        }

        guard let subscriptionFeatureName = SubscriptionFeatureName(rawValue: featureSelection.feature) else {
            assertionFailure("SubscriptionPagesUserScript: feature name does not matches mapping")
            return nil
        }

        switch subscriptionFeatureName {
        case .privateBrowsing:
            NotificationCenter.default.post(name: .openPrivateBrowsing, object: self, userInfo: nil)
        case .privateSearch:
            NotificationCenter.default.post(name: .openPrivateSearch, object: self, userInfo: nil)
        case .emailProtection:
            NotificationCenter.default.post(name: .openEmailProtection, object: self, userInfo: nil)
        case .appTrackingProtection:
            NotificationCenter.default.post(name: .openAppTrackingProtection, object: self, userInfo: nil)
        case .vpn:
            Pixel.fire(.privacyProWelcomeVPN, limitTo: .initial)
            NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: self, userInfo: nil)
        case .personalInformationRemoval:
            Pixel.fire(.privacyProWelcomePersonalInformationRemoval, limitTo: .initial)
            NotificationCenter.default.post(name: .openPersonalInformationRemoval, object: self, userInfo: nil)
            uiHandler.showDataBrokerProtectionTab()
        case .identityTheftRestoration:
            Pixel.fire(.privacyProWelcomeIdentityRestoration, limitTo: .initial)
            uiHandler.showIdentityTheftRestorationTab()
        }

        return nil
    }

    func completeStripePayment(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let progressViewController = uiHandler.presentProgressViewController(configuration: .completing)
        await stripePurchaseFlow.completeSubscriptionPurchase()
        uiHandler.dismiss(viewController: progressViewController)
        return [String: String]() // cannot be nil // TODO: why?
    }

    // MARK: Pixel related actions

    func subscriptionsMonthlyPriceClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        Pixel.fire(.privacyProOfferMonthlyPriceClick)
        return nil
    }

    func subscriptionsYearlyPriceClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        Pixel.fire(.privacyProOfferYearlyPriceClick)
        return nil
    }

    func subscriptionsUnknownPriceClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        // Not used
        return nil
    }

    func subscriptionsAddEmailSuccess(params: Any, original: WKScriptMessage) async -> Encodable? {
        Pixel.fire(.privacyProAddEmailSuccess, limitTo: .initial)
        return nil
    }

    func subscriptionsWelcomeFaqClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        Pixel.fire(.privacyProWelcomeFAQClick, limitTo: .initial)
        return nil
    }

    // MARK: Push actions

    enum SubscribeActionName: String {
        case onPurchaseUpdate
    }

    @MainActor
    func pushPurchaseUpdate(originalMessage: WKScriptMessage, purchaseUpdate: PurchaseUpdate) async {
        pushAction(method: .onPurchaseUpdate, webView: originalMessage.webView!, params: purchaseUpdate)
    }

    func pushAction(method: SubscribeActionName, webView: WKWebView, params: Encodable) {
        let broker = UserScriptMessageBroker(context: SubscriptionPagesUserScript.context, requiresRunInPageContentWorld: true )
        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }

    // MARK: - Errors handling

    fileprivate enum SubscriptionError: Error {
        case purchaseFailed,
             missingEntitlements,
             failedToGetSubscriptionOptions,
             failedToSetSubscription,
             failedToRestoreFromEmail,
             failedToRestoreFromEmailSubscriptionInactive,
             failedToRestorePastPurchase,
             subscriptionNotFound,
             subscriptionExpired,
             hasActiveSubscription,
             cancelledByUser,
             accountCreationFailed,
             activeSubscriptionAlreadyPresent,
             generalError
    }

    // swiftlint:disable:next cyclomatic_complexity
    fileprivate func report(subscriptionActivationError: SubscriptionError) {

        os_log(.error, log: .subscription, "Subscription purchase error: %{public}s", subscriptionActivationError.localizedDescription)

        var isStoreError = false
        var isBackendError = false

        switch subscriptionActivationError {
        case .purchaseFailed:
            isStoreError = true
        case .missingEntitlements:
            isBackendError = true
        case .failedToGetSubscriptionOptions:
            isStoreError = true
        case .failedToSetSubscription:
            isBackendError = true
        case .failedToRestoreFromEmail, .failedToRestoreFromEmailSubscriptionInactive:
            isBackendError = true
        case .failedToRestorePastPurchase:
            isStoreError = true
        case .subscriptionNotFound:
            DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreFailureNotFound, frequency: .dailyAndCount)
            isStoreError = true
        case .subscriptionExpired:
            isStoreError = true
        case .hasActiveSubscription:
            isStoreError = true
            isBackendError = true
        case .cancelledByUser: break
        case .accountCreationFailed:
            DailyPixel.fire(pixel: .privacyProPurchaseFailureAccountNotCreated, frequency: .dailyAndCount)
        case .activeSubscriptionAlreadyPresent: break
        case .generalError: break
        }

        if isStoreError {
            DailyPixel.fire(pixel: .privacyProPurchaseFailureStoreError, frequency: .dailyAndCount)
        }

        if isBackendError {
            DailyPixel.fire(pixel: .privacyProPurchaseFailureBackendError, frequency: .dailyAndCount)
        }

        if subscriptionActivationError != .hasActiveSubscription && subscriptionActivationError != .cancelledByUser {
            DailyPixel.fire(pixel: .privacyProPurchaseFailure, frequency: .dailyAndCount)
        }
    }

    @available(macOS 12.0, iOS 15.0, *)
    func startAppStoreRestoreFlow(onResultHandler: @escaping (Result<Void, AppStoreRestoreFlow.Error>) -> Void = {_ in}) {

        let progressViewController = uiHandler.presentProgressViewController(configuration: .restoring)
        defer { uiHandler.dismiss(viewController: progressViewController) }
        Task {
            guard case .success = await PurchaseManager.shared.syncAppleIDAccount() else {
                return
            }
            onResultHandler(await appStoreRestoreFlow.restoreAccountFromPastPurchase())
        }
    }
}

#endif
