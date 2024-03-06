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
    var broker: UserScriptMessageBroker?

    var featureName = "useSubscription"

    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [
        .exact(hostname: "duckduckgo.com"),
        .exact(hostname: "abrown.duckduckgo.com")
    ])

    func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch methodName {
        case "getSubscription": return getSubscription
        case "setSubscription": return setSubscription
        case "backToSettings": return backToSettings
        case "getSubscriptionOptions": return getSubscriptionOptions
        case "subscriptionSelected": return subscriptionSelected
        case "activateSubscription": return activateSubscription
        case "featureSelected": return featureSelected
        case "completeStripePayment": return completeStripePayment
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
        if let authToken = AccountManager().authToken, AccountManager().accessToken != nil {
            return Subscription(token: authToken)
        } else {
            return Subscription(token: "")
        }
    }

    func setSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let subscriptionValues: SubscriptionValues = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionValues")
            return nil
        }

        let authToken = subscriptionValues.token
        let accountManager = AccountManager()
        if case let .success(accessToken) = await accountManager.exchangeAuthTokenToAccessToken(authToken),
           case let .success(accountDetails) = await accountManager.fetchAccountDetails(with: accessToken) {
            accountManager.storeAuthToken(token: authToken)
            accountManager.storeAccount(token: accessToken, email: accountDetails.email, externalID: accountDetails.externalID)
        }

        return nil
    }

    func backToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let accountManager = AccountManager()
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
#if STRIPE
        switch await StripePurchaseFlow.subscriptionOptions() {
        case .success(let subscriptionOptions):
            return subscriptionOptions
        case .failure:
            return nil
        }
#else
        if #available(macOS 12.0, *) {
            switch await AppStorePurchaseFlow.subscriptionOptions() {
            case .success(let subscriptionOptions):
                return subscriptionOptions
            case .failure:
                return nil
            }
        }
        return nil
#endif
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func subscriptionSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        struct SubscriptionSelection: Decodable {
            let id: String
        }

        let message = original

#if STRIPE
        let emailAccessToken = try? EmailManager().getToken()

        switch await StripePurchaseFlow.prepareSubscriptionPurchase(emailAccessToken: emailAccessToken) {
        case .success(let purchaseUpdate):
            await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: purchaseUpdate)
        case .failure:
            await WindowControllersManager.shared.lastKeyMainWindowController?.showSomethingWentWrongAlert()
            return nil
        }
#else
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
                return nil
            }

            os_log(.info, log: .subscription, "[Purchase] Starting purchase for: %{public}s", subscriptionSelection.id)

            await mainViewController?.presentAsSheet(progressViewController)

            // Check for active subscriptions
            if await PurchaseManager.hasActiveSubscription() {
                os_log(.info, log: .subscription, "[Purchase] Found active subscription during purchase")
                await WindowControllersManager.shared.lastKeyMainWindowController?.showSubscriptionFoundAlert(originalMessage: message)
                return nil
            }

            let emailAccessToken = try? EmailManager().getToken()

            os_log(.info, log: .subscription, "[Purchase] Purchasing")
            switch await AppStorePurchaseFlow.purchaseSubscription(with: subscriptionSelection.id, emailAccessToken: emailAccessToken) {
            case .success:
                break
            case .failure(let error):
                switch error {
                case .cancelledByUser:
                    os_log(.error, log: .subscription, "[Purchase] Cancelled by user")
                default:
                    os_log(.error, log: .subscription, "[Purchase] Error: %{public}s", String(reflecting: error))
                    await WindowControllersManager.shared.lastKeyMainWindowController?.showSomethingWentWrongAlert()
                }
                return nil
            }

            await progressViewController.updateTitleText(UserText.completingPurchaseTitle)

            os_log(.info, log: .subscription, "[Purchase] Completing purchase")

            switch await AppStorePurchaseFlow.completeSubscriptionPurchase() {
            case .success(let purchaseUpdate):
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: purchaseUpdate)
            case .failure(let error):
                os_log(.error, log: .subscription, "[Purchase] Error: %{public}s", String(reflecting: error))
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: PurchaseUpdate(type: "completed"))
            }

            os_log(.info, log: .subscription, "[Purchase] Purchase complete")
        }
#endif

        return nil
    }

    func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let message = original

        Task { @MainActor in
            let actionHandlers = SubscriptionAccessActionHandlers(
                restorePurchases: {
                    SubscriptionPagesUseSubscriptionFeature.startAppStoreRestoreFlow {
                        message.webView?.reload()
                    }
                },
                openURLHandler: { url in
                    WindowControllersManager.shared.showTab(with: .subscription(url))
                })

            let vc = SubscriptionAccessViewController(actionHandlers: actionHandlers)
            WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.presentAsSheet(vc)
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
            NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: self, userInfo: nil)
        case .personalInformationRemoval:
            NotificationCenter.default.post(name: .openPersonalInformationRemoval, object: self, userInfo: nil)
            await WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
        case .identityTheftRestoration:
            await WindowControllersManager.shared.showTab(with: .identityTheftRestoration(.identityTheftRestoration))
        }

        return nil
    }

    func completeStripePayment(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let mainViewController = await WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
        let progressViewController = await ProgressViewController(title: UserText.completingPurchaseTitle)

        await mainViewController?.presentAsSheet(progressViewController)
        await StripePurchaseFlow.completeSubscriptionPurchase()
        await mainViewController?.dismiss(progressViewController)

        return [String: String]() // cannot be nil
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
}

extension SubscriptionPagesUseSubscriptionFeature {

    static func startAppStoreRestoreFlow(onSuccessHandler: @escaping () -> Void = {}) {
        if #available(macOS 12.0, *) {
            Task { @MainActor in
                let mainViewController = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
                let progressViewController = ProgressViewController(title: UserText.restoringSubscriptionTitle)

                defer { mainViewController?.dismiss(progressViewController) }

                mainViewController?.presentAsSheet(progressViewController)

                guard case .success = await PurchaseManager.shared.syncAppleIDAccount() else { return }

                switch await AppStoreRestoreFlow.restoreAccountFromPastPurchase() {
                case .success:
                    onSuccessHandler()
                case .failure(let error):
                    switch error {
                    case .missingAccountOrTransactions:
                        WindowControllersManager.shared.lastKeyMainWindowController?.showSubscriptionNotFoundAlert()
                    case .subscriptionExpired:
                        WindowControllersManager.shared.lastKeyMainWindowController?.showSubscriptionInactiveAlert()
                    default:
                        WindowControllersManager.shared.lastKeyMainWindowController?.showSomethingWentWrongAlert()
                    }
                }
            }
        }
    }
}

extension MainWindowController {

    @MainActor
    func showSomethingWentWrongAlert(environment: SubscriptionPurchaseEnvironment.Environment = SubscriptionPurchaseEnvironment.current) {
        guard let window else { return }

        switch environment {
        case .appStore:
            window.show(.somethingWentWrongAlert())
        case .stripe:
            window.show(.somethingWentWrongStripeAlert())
        }
    }

    @MainActor
    func showSubscriptionNotFoundAlert() {
        guard let window else { return }

        window.show(.subscriptionNotFoundAlert(), firstButtonAction: {
            WindowControllersManager.shared.show(url: .subscriptionPurchase, source: .ui, newTab: true)
        })
    }

    @MainActor
    func showSubscriptionInactiveAlert() {
        guard let window else { return }

        window.show(.subscriptionInactiveAlert(), firstButtonAction: {
            WindowControllersManager.shared.show(url: .subscriptionPurchase, source: .ui, newTab: true)
        })
    }

    @MainActor
    func showSubscriptionFoundAlert(originalMessage: WKScriptMessage) {
        guard let window else { return }

        window.show(.subscriptionFoundAlert(), firstButtonAction: {
            if #available(macOS 12.0, *) {
                Task {
                    _ = await AppStoreRestoreFlow.restoreAccountFromPastPurchase()
                    originalMessage.webView?.reload()
                }
            }
        })
    }
}

#endif
