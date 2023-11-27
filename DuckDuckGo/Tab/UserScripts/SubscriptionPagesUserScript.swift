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
import Account
import Purchase
import Subscription

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
        let authToken = AccountManager().authToken ?? ""
        return Subscription(token: authToken)
    }

    func setSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let subscriptionValues: SubscriptionValues = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionValues")
            return nil
        }

        await AccountManager().exchangeAndStoreTokens(with: subscriptionValues.token)
        return nil
    }

    func backToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await AccountManager().refreshAccountData()

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
            // TODO: handle errors - no products found
            return nil
        }
#else
        if #available(macOS 12.0, *) {
            switch await AppStorePurchaseFlow.subscriptionOptions() {
            case .success(let subscriptionOptions):
                return subscriptionOptions
            case .failure:
                // TODO: handle errors - no products found
                return nil
            }
        }
        return nil
#endif
    }

    func subscriptionSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        struct SubscriptionSelection: Decodable {
            let id: String
        }

        let message = original

#if STRIPE
        switch await StripePurchaseFlow.prepareSubscriptionPurchase(emailAccessToken: "passemailaccesstokenhere") {
        case .success(let purchaseUpdate):
            await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: purchaseUpdate)
        case .failure:
            // TODO: handle errors - failed prepare purchae
            return nil
        }
#else
        if #available(macOS 12.0, *) {
            guard let subscriptionSelection: SubscriptionSelection = DecodableHelper.decode(from: params) else {
                assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionSelection")
                return nil
            }

            print("Selected: \(subscriptionSelection.id)")

            await showProgress(with: "Purchase in progress...")

            // Hide it after some time in case nothing happens
            /*
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                print("hiding it since nothing happened!")
                self.hideProgress()
            }
             */

            let emailAccessToken = try? EmailManager().getToken()

            switch await AppStorePurchaseFlow.purchaseSubscription(with: subscriptionSelection.id, emailAccessToken: emailAccessToken) {
            case .success:
                break
            case .failure(let error):
                if error != .appStoreAuthenticationFailed {
                    await showSomethingWentWrongAlert()
                }

                await hideProgress()
                return nil
            }

            await updateProgressTitle("Completing purchase...")

            switch await AppStorePurchaseFlow.completeSubscriptionPurchase() {
            case .success(let purchaseUpdate):
                await pushPurchaseUpdate(originalMessage: message, purchaseUpdate: purchaseUpdate)
            case .failure:
                // TODO: handle errors - missing entitlements on post purchase check
                return nil
            }

            await hideProgress()
        }
#endif

        return nil
    }

    private weak var purchaseInProgressViewController: PurchaseInProgressViewController?

    @MainActor
    private func showProgress(with title: String) {
        guard purchaseInProgressViewController == nil else { return }
        let progressVC = PurchaseInProgressViewController(title: title)
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.presentAsSheet(progressVC)
        purchaseInProgressViewController = progressVC
    }

    @MainActor
    private func updateProgressTitle(_ title: String) {
        guard let purchaseInProgressViewController else { return }
        purchaseInProgressViewController.updateTitleText(title)
    }

    @MainActor
    private func hideProgress() {
        guard let purchaseInProgressViewController else { return }
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.dismiss(purchaseInProgressViewController)
        self.purchaseInProgressViewController = nil
    }

    func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        print(">>> Selected to activate a subscription -- show the activation settings screen")

        let message = original

        Task { @MainActor in
            let actionHandlers = SubscriptionAccessActionHandlers(
                restorePurchases: {
                    if #available(macOS 12.0, *) {
                        Task {
                            guard case .success = await PurchaseManager.shared.syncAppleIDAccount() else { return }

                            guard case .success = await AppStoreRestoreFlow.restoreAccountFromPastPurchase() else {
                                self.showSubscriptionNotFoundAlert()
                                return
                            }

                            guard let token = AccountManager().accessToken else { return }

                            if case .success(let response) = await SubscriptionService.getSubscriptionInfo(token: token) {
                                if response.status == "Expired" {
                                    self.showSubscriptionInactiveAlert()
                                }
                            }

                            message.webView?.reload()
                        }
                    }
                },
                openURLHandler: { url in
                    WindowControllersManager.shared.show(url: url, newTab: true)
                }, goToSyncPreferences: {
                    WindowControllersManager.shared.show(url: URL(string: "about:preferences/sync")!, newTab: true)
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

        print(">>> Selected a feature -- show the corresponding UI", featureSelection)
        return nil
    }

    func completeStripePayment(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        print(">>> completeStripePayment")

        await showProgress(with: "Completing purchase...")
        await StripePurchaseFlow.completeSubscriptionPurchase()
        await hideProgress()

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

        print(">>> Pushing into WebView:", method.rawValue, String(describing: params))
        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }

    // MARK: Alerts

    @MainActor
    private func showSomethingWentWrongAlert() {
        guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

        let alert = NSAlert.somethingWentWrongAlert()
        alert.beginSheetModal(for: window)
    }

    @MainActor
    private func showSubscriptionNotFoundAlert() {
        guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

        let alert = NSAlert.subscriptionNotFoundAlert()
        alert.beginSheetModal(for: window, completionHandler: { response in
            if case .alertFirstButtonReturn = response {
                WindowControllersManager.shared.show(url: .purchaseSubscription, newTab: true)
            }
        })
    }

    @MainActor
    private func showSubscriptionInactiveAlert() {
        guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

        let alert = NSAlert.subscriptionInactiveAlert()
        alert.beginSheetModal(for: window, completionHandler: { response in
            if case .alertFirstButtonReturn = response {
                WindowControllersManager.shared.show(url: .purchaseSubscription, newTab: true)
                AccountManager().signOut()
            }
        })
    }

    @MainActor
    private func showSubscriptionFoundAlert() {
        guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

        let alert = NSAlert.subscriptionFoundAlert()
        alert.beginSheetModal(for: window, completionHandler: { response in
            if case .alertFirstButtonReturn = response {
                // restore
            } else {
                // clear
            }

            print("Restore action")
        })
    }
}

#endif
