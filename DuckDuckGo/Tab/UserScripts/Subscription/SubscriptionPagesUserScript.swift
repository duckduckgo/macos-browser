//
//  SubscriptionPagesUserScript.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Foundation
import BrowserServicesKit
import Common
import Combine
import Navigation
import WebKit
import UserScript
import Subscription
import PixelKit

public extension Notification.Name {
    static let subscriptionPageCloseAndOpenPreferences = Notification.Name("com.duckduckgo.subscriptionPage.CloseAndOpenPreferences")
}

/// The user script that will be the broker for all subscription features
public final class SubscriptionPagesUserScript: NSObject, UserScript, UserScriptMessaging {
    public var source: String = ""

    public static let context = "subscriptionPages"

    // special pages messaging cannot be isolated as we'll want regular page-scripts to be able to communicate
    public let broker = UserScriptMessageBroker(context: SubscriptionPagesUserScript.context, requiresRunInPageContentWorld: true )

    public let messageNames: [String] = [
        SubscriptionPagesUserScript.context
    ]

    public let injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
}

extension SubscriptionPagesUserScript: WKScriptMessageHandlerWithReply {
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) async -> (Any?, String?) {
        let action = broker.messageHandlerFor(message)
        do {
            let json = try await broker.execute(action: action, original: message)
            return (json, nil)
        } catch {
            // forward uncaught errors to the client
            return (nil, error.localizedDescription)
        }
    }
}

/// Fallback for macOS 10.15
extension SubscriptionPagesUserScript: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // unsupported
    }
}

/// Use Subscription sub-feature
final class SubscriptionPagesUseSubscriptionFeature: Subfeature {
    weak var broker: UserScriptMessageBroker?
    var featureName = "useSubscription"
    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [
        .exact(hostname: "duckduckgo.com"),
        .exact(hostname: "abrown.duckduckgo.com")
    ])
    let subscriptionManager: SubscriptionManager
    var accountManager: AccountManager { subscriptionManager.accountManager }
    var subscriptionPlatform: SubscriptionEnvironment.PurchasePlatform { subscriptionManager.currentEnvironment.purchasePlatform }

    let stripePurchaseFlow: StripePurchaseFlow
    let subscriptionErrorReporter = SubscriptionErrorReporter()
    let subscriptionSuccessPixelHandler: SubscriptionAttributionPixelHandler
    let uiHandler: SubscriptionUIHandling

    public init(subscriptionManager: SubscriptionManager,
                subscriptionSuccessPixelHandler: SubscriptionAttributionPixelHandler = PrivacyProSubscriptionAttributionPixelHandler(),
                stripePurchaseFlow: StripePurchaseFlow,
                uiHandler: SubscriptionUIHandling) {
        self.subscriptionManager = subscriptionManager
        self.stripePurchaseFlow = stripePurchaseFlow
        self.subscriptionSuccessPixelHandler = subscriptionSuccessPixelHandler
        self.uiHandler = uiHandler
    }

    func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

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
        static let getAccessToken = "getAccessToken"
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
        case Handlers.getAccessToken: return getAccessToken
        default:
            return nil
        }
    }

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
        let authToken = accountManager.authToken ?? ""
        return Subscription(token: authToken)
    }

    func setSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {

        PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseEmailSuccess, frequency: .dailyAndCount)

        guard let subscriptionValues: SubscriptionValues = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionValues")
            return nil
        }

        let authToken = subscriptionValues.token
        if case let .success(accessToken) = await accountManager.exchangeAuthTokenToAccessToken(authToken),
           case let .success(accountDetails) = await accountManager.fetchAccountDetails(with: accessToken) {
            accountManager.storeAuthToken(token: authToken)
            accountManager.storeAccount(token: accessToken, email: accountDetails.email, externalID: accountDetails.externalID)
        }

        return nil
    }

    func backToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if let accessToken = accountManager.accessToken,
           case let .success(accountDetails) = await accountManager.fetchAccountDetails(with: accessToken) {
            accountManager.storeAccount(token: accessToken, email: accountDetails.email, externalID: accountDetails.externalID)
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .subscriptionPageCloseAndOpenPreferences, object: self)
        }

        return nil
    }

    func getSubscriptionOptions(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard DefaultSubscriptionFeatureAvailability().isSubscriptionPurchaseAllowed else { return SubscriptionOptions.empty }

        switch subscriptionPlatform {
        case .appStore:
            if #available(macOS 12.0, *) {
                return await subscriptionManager.storePurchaseManager().subscriptionOptions()
            }
        case .stripe:
            switch await stripePurchaseFlow.subscriptionOptions() {
            case .success(let subscriptionOptions):
                return subscriptionOptions
            case .failure:
                break
            }
        }

        return SubscriptionOptions.empty
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func subscriptionSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        PixelKit.fire(PrivacyProPixel.privacyProPurchaseAttempt, frequency: .dailyAndCount)
        struct SubscriptionSelection: Decodable {
            let id: String
        }

        let message = original

        // Extract the origin from the webview URL to use for attribution pixel.
        subscriptionSuccessPixelHandler.origin = await originFrom(originalMessage: message)
        if subscriptionManager.currentEnvironment.purchasePlatform == .appStore {
            if #available(macOS 12.0, *) {
                guard let subscriptionSelection: SubscriptionSelection = DecodableHelper.decode(from: params) else {
                    assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionSelection")
                    subscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                    await uiHandler.dismissProgressViewController()
                    return nil
                }

                os_log(.info, log: .subscription, "[Purchase] Starting purchase for: %{public}s", subscriptionSelection.id)

                await uiHandler.presentProgressViewController(withTitle: UserText.purchasingSubscriptionTitle)

                // Check for active subscriptions
                if await subscriptionManager.storePurchaseManager().hasActiveSubscription() {
                    PixelKit.fire(PrivacyProPixel.privacyProRestoreAfterPurchaseAttempt)
                    os_log(.info, log: .subscription, "[Purchase] Found active subscription during purchase")
                    subscriptionErrorReporter.report(subscriptionActivationError: .hasActiveSubscription)
                    await showSubscriptionFoundAlert(originalMessage: message)
                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
                    return nil
                }

                let emailAccessToken = try? EmailManager().getToken()
                let purchaseTransactionJWS: String
                let appStorePurchaseFlow = DefaultAppStorePurchaseFlow(subscriptionManager: subscriptionManager,
                                                                appStoreRestoreFlow: DefaultAppStoreRestoreFlow(subscriptionManager: subscriptionManager))

                os_log(.info, log: .subscription, "[Purchase] Purchasing")
                switch await appStorePurchaseFlow.purchaseSubscription(with: subscriptionSelection.id, emailAccessToken: emailAccessToken) {
                case .success(let transactionJWS):
                    purchaseTransactionJWS = transactionJWS
                case .failure(let error):
                    switch error {
                    case .noProductsFound:
                        subscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                    case .activeSubscriptionAlreadyPresent:
                        subscriptionErrorReporter.report(subscriptionActivationError: .activeSubscriptionAlreadyPresent)
                    case .authenticatingWithTransactionFailed:
                        subscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                    case .accountCreationFailed:
                        subscriptionErrorReporter.report(subscriptionActivationError: .accountCreationFailed)
                    case .purchaseFailed:
                        subscriptionErrorReporter.report(subscriptionActivationError: .purchaseFailed)
                    case .cancelledByUser:
                        subscriptionErrorReporter.report(subscriptionActivationError: .cancelledByUser)
                    case .missingEntitlements:
                        subscriptionErrorReporter.report(subscriptionActivationError: .missingEntitlements)
                    case .internalError:
                        assertionFailure("Internal error")
                    }

                    if error != .cancelledByUser {
                        await showSomethingWentWrongAlert()
                    } else {
                        await uiHandler.dismissProgressViewController()
                    }
                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
                    return nil
                }

                await uiHandler.updateProgressViewController(title: UserText.completingPurchaseTitle)

                os_log(.info, log: .subscription, "[Purchase] Completing purchase")
                let completePurchaseResult = await appStorePurchaseFlow.completeSubscriptionPurchase(with: purchaseTransactionJWS)
                switch completePurchaseResult {
                case .success(let purchaseUpdate):
                    os_log(.info, log: .subscription, "[Purchase] Purchase complete")
                    PixelKit.fire(PrivacyProPixel.privacyProPurchaseSuccess, frequency: .dailyAndCount)
                    PixelKit.fire(PrivacyProPixel.privacyProSubscriptionActivated, frequency: .unique)
                    subscriptionSuccessPixelHandler.fireSuccessfulSubscriptionAttributionPixel()
                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: purchaseUpdate)
                case .failure(let error):
                    switch error {
                    case .noProductsFound:
                        subscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                    case .activeSubscriptionAlreadyPresent:
                        subscriptionErrorReporter.report(subscriptionActivationError: .activeSubscriptionAlreadyPresent)
                    case .authenticatingWithTransactionFailed:
                        subscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                    case .accountCreationFailed:
                        subscriptionErrorReporter.report(subscriptionActivationError: .accountCreationFailed)
                    case .purchaseFailed:
                        subscriptionErrorReporter.report(subscriptionActivationError: .purchaseFailed)
                    case .cancelledByUser:
                        subscriptionErrorReporter.report(subscriptionActivationError: .cancelledByUser)
                    case .missingEntitlements:
                        subscriptionErrorReporter.report(subscriptionActivationError: .missingEntitlements)
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .subscriptionPageCloseAndOpenPreferences, object: self)
                        }
                        await uiHandler.dismissProgressViewController()
                        return nil
                    case .internalError:
                        assertionFailure("Internal error")
                    }

                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "completed"))
                }
            }
        } else if subscriptionPlatform == .stripe {
            let emailAccessToken = try? EmailManager().getToken()
            let result = await stripePurchaseFlow.prepareSubscriptionPurchase(emailAccessToken: emailAccessToken)
            switch result {
            case .success(let success):
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: success)
            case .failure(let error):
                await showSomethingWentWrongAlert()
                switch error {
                case .noProductsFound:
                    subscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                case .accountCreationFailed:
                    subscriptionErrorReporter.report(subscriptionActivationError: .accountCreationFailed)
                }
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
            }
        }

        await uiHandler.dismissProgressViewController()
        return nil
    }

    // MARK: functions used in SubscriptionAccessActionHandlers

    func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseOfferPageEntry)
        Task { @MainActor in
            uiHandler.presentSubscriptionAccessViewController(handler: self, message: original)
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
            PixelKit.fire(PrivacyProPixel.privacyProWelcomeVPN, frequency: .unique)
            NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: self, userInfo: nil)
        case .personalInformationRemoval:
            PixelKit.fire(PrivacyProPixel.privacyProWelcomePersonalInformationRemoval, frequency: .unique)
            NotificationCenter.default.post(name: .openPersonalInformationRemoval, object: self, userInfo: nil)
            await uiHandler.showTab(with: .dataBrokerProtection)
        case .identityTheftRestoration:
            PixelKit.fire(PrivacyProPixel.privacyProWelcomeIdentityRestoration, frequency: .unique)
            let url = subscriptionManager.url(for: .identityTheftRestoration)
            await uiHandler.showTab(with: .identityTheftRestoration(url))
        }

        return nil
    }

    func completeStripePayment(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await uiHandler.presentProgressViewController(withTitle: UserText.completingPurchaseTitle)
        await stripePurchaseFlow.completeSubscriptionPurchase()
        await uiHandler.dismissProgressViewController()

        PixelKit.fire(PrivacyProPixel.privacyProPurchaseStripeSuccess, frequency: .dailyAndCount)
        subscriptionSuccessPixelHandler.fireSuccessfulSubscriptionAttributionPixel()
        return [String: String]() // cannot be nil, the web app expect something back before redirecting the user to the final page
    }

    // MARK: Pixel related actions

    func subscriptionsMonthlyPriceClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        PixelKit.fire(PrivacyProPixel.privacyProOfferMonthlyPriceClick)
        return nil
    }

    func subscriptionsYearlyPriceClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        PixelKit.fire(PrivacyProPixel.privacyProOfferYearlyPriceClick)
        return nil
    }

    func subscriptionsUnknownPriceClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        // Not used
        return nil
    }

    func subscriptionsAddEmailSuccess(params: Any, original: WKScriptMessage) async -> Encodable? {
        PixelKit.fire(PrivacyProPixel.privacyProAddEmailSuccess, frequency: .unique)
        return nil
    }

    func subscriptionsWelcomeFaqClicked(params: Any, original: WKScriptMessage) async -> Encodable? {
        PixelKit.fire(PrivacyProPixel.privacyProWelcomeFAQClick, frequency: .unique)
        return nil
    }

    func getAccessToken(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if let accessToken = accountManager.accessToken {
            return ["token": accessToken]
        } else {
            return [String: String]()
        }
    }

    // MARK: Push actions

    enum SubscribeActionName: String {
        case onPurchaseUpdate
    }

    @MainActor
    func pushPurchaseUpdate(originalMessage: WKScriptMessage, purchaseUpdate: PurchaseUpdate) {
        pushAction(method: .onPurchaseUpdate, webView: originalMessage.webView!, params: purchaseUpdate)
    }

    func pushAction(method: SubscribeActionName, webView: WKWebView, params: Encodable) {
        guard let broker else {
            assertionFailure("Cannot continue without broker instance")
            return
        }

        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }

    @MainActor
    private func originFrom(originalMessage: WKScriptMessage) -> String? {
        let url = originalMessage.webView?.url
        return url?.getParameter(named: AttributionParameter.origin)
    }

    // MARK: - UI interactions

    func showSomethingWentWrongAlert() async {
        PixelKit.fire(PrivacyProPixel.privacyProPurchaseFailure, frequency: .dailyAndCount)
        switch await uiHandler.dismissProgressViewAndShow(alertType: .somethingWentWrong, text: nil) {
        case .alertFirstButtonReturn:
            let url = subscriptionManager.url(for: .purchase)
            await uiHandler.showTab(with: .subscription(url))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        default: return
        }
    }

    func showSubscriptionFoundAlert(originalMessage: WKScriptMessage) async {

        switch await uiHandler.dismissProgressViewAndShow(alertType: .subscriptionFound, text: nil) {
        case .alertFirstButtonReturn:
            if #available(macOS 12.0, *) {
                let appStoreRestoreFlow = DefaultAppStoreRestoreFlow(subscriptionManager: self.subscriptionManager)
                let result = await appStoreRestoreFlow.restoreAccountFromPastPurchase()
                switch result {
                case .success: PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseStoreSuccess, frequency: .dailyAndCount)
                case .failure: break
                }
                Task { @MainActor in
                    originalMessage.webView?.reload()
                }
            }
        default: return
        }
    }
}

extension SubscriptionPagesUseSubscriptionFeature: SubscriptionAccessActionHandling {

    func subscriptionAccessActionRestorePurchases(message: WKScriptMessage) {
        if #available(macOS 12.0, *) {
            Task { @MainActor in
                let subscriptionAppStoreRestorer = SubscriptionAppStoreRestorer(subscriptionManager: self.subscriptionManager,
                                                                                uiHandler: self.uiHandler)
                await subscriptionAppStoreRestorer.restoreAppStoreSubscription()
                message.webView?.reload()
            }
        }
    }

    func subscriptionAccessActionOpenURLHandler(url: URL) {
        Task {
            await self.uiHandler.showTab(with: .subscription(url))
        }
    }

    func subscriptionAccessActionHandleAction(event: SubscriptionAccessActionHandlingEvent) {
        switch event {
        case .activateAddEmailClick:
            PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseEmailStart, frequency: .dailyAndCount)
        default: break
        }
    }
}
