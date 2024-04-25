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

import BrowserServicesKit
import Common
import Combine
import Foundation
import Navigation
import WebKit
import UserScript
import Subscription
import SubscriptionUI
import PixelKit

public extension Notification.Name {
    static let subscriptionPageCloseAndOpenPreferences = Notification.Name("com.duckduckgo.subscriptionPage.CloseAndOpenPreferences")
}

///
/// The user script that will be the broker for all subscription features
///
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

// MARK: - Fallback for macOS 10.15
extension SubscriptionPagesUserScript: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // unsupported
    }
}

///
/// Use Subscription sub-feature
///
final class SubscriptionPagesUseSubscriptionFeature: Subfeature {
    weak var broker: UserScriptMessageBroker?
    var featureName = "useSubscription"
    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [
        .exact(hostname: "duckduckgo.com"),
        .exact(hostname: "abrown.duckduckgo.com")
    ])

    let accountManager = AccountManager(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))

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
        guard let accessToken = accountManager.accessToken,
              let authToken = accountManager.authToken
        else { return Subscription(token: "") }

        if case .success(let subscription) = await SubscriptionService.getSubscription(accessToken: accessToken),
           subscription.isActive {
            return Subscription(token: authToken)
        } else {
            return Subscription(token: "")
        }
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

        if SubscriptionPurchaseEnvironment.current == .appStore {
            if #available(macOS 12.0, *) {
                switch await AppStorePurchaseFlow.subscriptionOptions() {
                case .success(let subscriptionOptions):
                    return subscriptionOptions
                case .failure:
                    break
                }
            }
        } else if SubscriptionPurchaseEnvironment.current == .stripe {
            switch await StripePurchaseFlow.subscriptionOptions() {
            case .success(let subscriptionOptions):
                return subscriptionOptions
            case .failure:
                break
            }
        }

        return SubscriptionOptions.empty
    }

    let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func subscriptionSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {

        PixelKit.fire(PrivacyProPixel.privacyProPurchaseAttempt, frequency: .dailyAndCount)
        struct SubscriptionSelection: Decodable {
            let id: String
        }

        let message = original

        if SubscriptionPurchaseEnvironment.current == .appStore {
            if #available(macOS 12.0, *) {
                let mainViewController = await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
                let progressViewController = await ProgressViewController(title: UserText.purchasingSubscriptionTitle)

                defer {
                    Task {
                        await mainViewController?.dismiss(progressViewController)
                    }
                }

                guard let subscriptionSelection: SubscriptionSelection = DecodableHelper.decode(from: params) else {
                    assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionSelection")
                    SubscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                    return nil
                }

                os_log(.info, log: .subscription, "[Purchase] Starting purchase for: %{public}s", subscriptionSelection.id)

                await mainViewController?.presentAsSheet(progressViewController)

                // Check for active subscriptions
                if await PurchaseManager.hasActiveSubscription() {
                    PixelKit.fire(PrivacyProPixel.privacyProRestoreAfterPurchaseAttempt)
                    os_log(.info, log: .subscription, "[Purchase] Found active subscription during purchase")
                    SubscriptionErrorReporter.report(subscriptionActivationError: .hasActiveSubscription)
                    await WindowControllersManager.shared.lastKeyMainWindowController?.showSubscriptionFoundAlert(originalMessage: message)
                    return nil
                }

                let emailAccessToken = try? EmailManager().getToken()
                let purchaseTransactionJWS: String

                os_log(.info, log: .subscription, "[Purchase] Purchasing")
                switch await AppStorePurchaseFlow.purchaseSubscription(with: subscriptionSelection.id, emailAccessToken: emailAccessToken, subscriptionAppGroup: subscriptionAppGroup) {
                case .success(let transactionJWS):
                    purchaseTransactionJWS = transactionJWS
                case .failure(let error):
                    switch error {
                    case .noProductsFound:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                    case .activeSubscriptionAlreadyPresent:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .activeSubscriptionAlreadyPresent)
                    case .authenticatingWithTransactionFailed:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                    case .accountCreationFailed:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .accountCreationFailed)
                    case .purchaseFailed:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .purchaseFailed)
                    case .cancelledByUser:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .cancelledByUser)
                    case .missingEntitlements:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .missingEntitlements)
                    }

                    if error != .cancelledByUser {
                        await WindowControllersManager.shared.lastKeyMainWindowController?.showSomethingWentWrongAlert()
                    }
                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
                    return nil
                }

                await progressViewController.updateTitleText(UserText.completingPurchaseTitle)

                os_log(.info, log: .subscription, "[Purchase] Completing purchase")

                switch await AppStorePurchaseFlow.completeSubscriptionPurchase(with: purchaseTransactionJWS, subscriptionAppGroup: subscriptionAppGroup) {
                case .success(let purchaseUpdate):
                    os_log(.info, log: .subscription, "[Purchase] Purchase complete")
                    PixelKit.fire(PrivacyProPixel.privacyProPurchaseSuccess, frequency: .dailyAndCount)
                    PixelKit.fire(PrivacyProPixel.privacyProSubscriptionActivated, frequency: .unique)
                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: purchaseUpdate)
                case .failure(let error):
                    switch error {
                    case .noProductsFound:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                    case .activeSubscriptionAlreadyPresent:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .activeSubscriptionAlreadyPresent)
                    case .authenticatingWithTransactionFailed:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .generalError)
                    case .accountCreationFailed:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .accountCreationFailed)
                    case .purchaseFailed:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .purchaseFailed)
                    case .cancelledByUser:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .cancelledByUser)
                    case .missingEntitlements:
                        SubscriptionErrorReporter.report(subscriptionActivationError: .missingEntitlements)
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .subscriptionPageCloseAndOpenPreferences, object: self)
                        }
                        return nil
                    }

                    await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "completed"))
                }
            }
        } else if SubscriptionPurchaseEnvironment.current == .stripe {
            let emailAccessToken = try? EmailManager().getToken()

            let result = await StripePurchaseFlow.prepareSubscriptionPurchase(emailAccessToken: emailAccessToken, subscriptionAppGroup: subscriptionAppGroup)

            switch result {
            case .success(let success):
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: success)
            case .failure(let error):
                await WindowControllersManager.shared.lastKeyMainWindowController?.showSomethingWentWrongAlert()

                switch error {
                case .noProductsFound:
                    SubscriptionErrorReporter.report(subscriptionActivationError: .subscriptionNotFound)
                case .accountCreationFailed:
                    SubscriptionErrorReporter.report(subscriptionActivationError: .accountCreationFailed)
                }
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "canceled"))
            }
        }

        return nil
    }

    func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {

        PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseOfferPageEntry)
        guard let mainViewController = await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController,
              let windowControllerManager = await WindowControllersManager.shared.lastKeyMainWindowController else {
            return nil
        }
        let message = original

        let actionHandlers = SubscriptionAccessActionHandlers(restorePurchases: {
            if #available(macOS 12.0, *) {
                Task { @MainActor in
                    await SubscriptionAppStoreRestorer.restoreAppStoreSubscription(mainViewController: mainViewController, windowController: windowControllerManager)
                    message.webView?.reload()
                }
            }
        }, openURLHandler: { url in
            DispatchQueue.main.async {
                WindowControllersManager.shared.showTab(with: .subscription(url))
            }
        }, uiActionHandler: { event in
            switch event {
            case .activateAddEmailClick:
                PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseEmailStart, frequency: .dailyAndCount)
            default:
                break
            }
        })

        let vc = await SubscriptionAccessViewController(accountManager: accountManager, actionHandlers: actionHandlers, subscriptionAppGroup: subscriptionAppGroup)
        await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.presentAsSheet(vc)

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
            await WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
        case .identityTheftRestoration:
            PixelKit.fire(PrivacyProPixel.privacyProWelcomeIdentityRestoration, frequency: .unique)
            await WindowControllersManager.shared.showTab(with: .identityTheftRestoration(.identityTheftRestoration))
        }

        return nil
    }

    func completeStripePayment(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let mainViewController = await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
        let progressViewController = await ProgressViewController(title: UserText.completingPurchaseTitle)

        await mainViewController?.presentAsSheet(progressViewController)
        await StripePurchaseFlow.completeSubscriptionPurchase(subscriptionAppGroup: subscriptionAppGroup)
        await mainViewController?.dismiss(progressViewController)

        PixelKit.fire(PrivacyProPixel.privacyProPurchaseStripeSuccess, frequency: .dailyAndCount)
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

    // MARK: Push actions

    enum SubscribeActionName: String {
        case onPurchaseUpdate
    }

    @MainActor
    func pushPurchaseUpdate(originalMessage: WKScriptMessage, purchaseUpdate: PurchaseUpdate) async {
        pushAction(method: .onPurchaseUpdate, webView: originalMessage.webView!, params: purchaseUpdate)
    }

    func pushAction(method: SubscribeActionName, webView: WKWebView, params: Encodable) {
        guard let broker else {
            assertionFailure("Cannot continue without broker instance")
            return
        }

        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }
}

extension MainWindowController {

    @MainActor
    func showSomethingWentWrongAlert() {
        PixelKit.fire(PrivacyProPixel.privacyProPurchaseFailure, frequency: .dailyAndCount)
        guard let window else { return }

        window.show(.somethingWentWrongAlert())
    }

    @MainActor
    func showSubscriptionNotFoundAlert() {
        guard let window else { return }

        window.show(.subscriptionNotFoundAlert(), firstButtonAction: {
            WindowControllersManager.shared.showTab(with: .subscription(.subscriptionPurchase))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        })
    }

    @MainActor
    func showSubscriptionInactiveAlert() {
        guard let window else { return }

        window.show(.subscriptionInactiveAlert(), firstButtonAction: {
            WindowControllersManager.shared.showTab(with: .subscription(.subscriptionPurchase))
            PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
        })
    }

    @MainActor
    func showSubscriptionFoundAlert(originalMessage: WKScriptMessage) {
        guard let window else { return }

        window.show(.subscriptionFoundAlert(), firstButtonAction: {
            if #available(macOS 12.0, *) {
                Task {
                    let result = await AppStoreRestoreFlow.restoreAccountFromPastPurchase(subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))
                    switch result {
                    case .success:
                        PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseStoreSuccess, frequency: .dailyAndCount)
                    case .failure: break
                    }
                    originalMessage.webView?.reload()
                }
            }
        })
    }
}
