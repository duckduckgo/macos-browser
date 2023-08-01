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
/// Use Email sub-feature
///
struct SubscriptionPagesUseSubscriptionFeature: Subfeature {
    weak var broker: UserScriptMessageBroker?

    var featureName = "useSubscription"

    var messageOriginPolicy: MessageOriginPolicy = .all

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch methodName {
        case "getSubscription": return getSubscription
        case "setSubscription": return setSubscription
        case "backToSettings": return backToSettings
        case "getSubscriptionOptions": return getSubscriptionOptions
        case "subscriptionSelected": return subscriptionSelected
        case "activateSubscription": return activateSubscription
        case "featureSelected": return featureSelected
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

    struct EmailProtectionValues: Codable {
        enum CodingKeys: String, CodingKey {
            case token
            case user
            case cohort
        }
        let token: String
        let user: String
        let cohort: String
    }

    struct SubscriptionCost: Codable {
        enum CodingKeys: String, CodingKey {
            case displayPrice
            case price
            case currency
            case recurrence
        }
        let displayPrice: String
        let price: Int
        let currency: String
        let recurrence: String
    }

    struct SubscriptionFeature: Codable {
        enum CodingKeys: String, CodingKey {
            case name
        }
        let name: String
    }

    struct SubscriptionOption: Codable {
        enum CodingKeys: String, CodingKey {
            case id
            case type
            case cost
        }
        let id: String
        let type: String
        let cost: SubscriptionCost
    }

    struct SubscriptionSelection: Codable {
        enum CodingKeys: String, CodingKey {
            case id
        }
        let id: String
    }

    struct FeatureSelection: Codable {
        enum CodingKeys: String, CodingKey {
            case feature
        }
        let feature: String
    }

    struct SubscriptionOptionsData: Codable {
        enum CodingKeys: String, CodingKey {
            case platform
            case features
            case options
        }
        let platform: String
        let features: [SubscriptionFeature]
        let options: [SubscriptionOption]
    }

    enum SubscribeActionName: String {
        case onPurchaseUpdate
    }

    struct PurchaseUpdate: Codable {
        enum CodingKeys: String, CodingKey {
            case type
        }
        let type: String
    }

    func getSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let token = AccountManager().shortLivedToken ?? ""
        let subscription = Subscription(token: token)
        return subscription
    }

    func setSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let subscriptionValues: SubscriptionValues = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionValues")
            return nil
        }

        AccountManager().exchangeTokenAndRefreshEntitlements(with: subscriptionValues.token)
        return nil
    }

    func backToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .subscriptionPageCloseAndOpenPreferences, object: self)
        }

        return nil
    }

    func getSubscriptionOptions(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        let features = [
            SubscriptionFeature(name: "private-browsing"),
            SubscriptionFeature(name: "private-search"),
            SubscriptionFeature(name: "email-protection"),
            SubscriptionFeature(name: "app-tracking-protection"),
            SubscriptionFeature(name: "vpn"),
            SubscriptionFeature(name: "personal-information-removal"),
            SubscriptionFeature(name: "identity-theft-restoration"),
        ]
        let subscriptionOptions = [
            SubscriptionOption(
                id: "bundle_1",
                type: "auto-renewable",
                cost: SubscriptionCost(displayPrice: "$9.99", price: 999, currency: "USD", recurrence: "monthly")
            ),
            SubscriptionOption(
                id: "bundle_2",
                type: "auto-renewable",
                cost: SubscriptionCost(displayPrice: "$99.99", price: 9999, currency: "USD", recurrence: "yearly")
            )
        ]

        return SubscriptionOptionsData(
            platform: "macos",
            features: features,
            options: subscriptionOptions
        )
    }

    func subscriptionSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let subscriptionSelection: SubscriptionSelection = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionSelection")
            return nil
        }

        print(">>> Selected subscription", subscriptionSelection.id)

        // Demo delay before messaging the web front-end
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Change `2.0` to the desired number of seconds.
            pushAction(method: SubscribeActionName.onPurchaseUpdate, webView: original.webView!, params: PurchaseUpdate(type: "completed"))
        }

        return nil
    }

    func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        print(">>> Selected to activate a subscription -- show the activation settings screen")
        return nil
    }

    func featureSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let featureSelection: FeatureSelection = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of FeatureSelection")
            return nil
        }

        print(">>> Selected a feature -- show the corresponding UI", featureSelection)
        return nil
    }

    func pushAction(method: SubscribeActionName, webView: WKWebView, params: Encodable) {
        let broker = UserScriptMessageBroker(context: SubscriptionPagesUserScript.context, requiresRunInPageContentWorld: true )

        print(">>> Pushing into WebView:", method.rawValue, String(describing: params))
        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }

}

#endif
