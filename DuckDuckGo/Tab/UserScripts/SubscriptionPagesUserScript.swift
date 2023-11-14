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
        let token = AccountManager().authToken ?? ""
        let subscription = Subscription(token: token)
        return subscription
    }

    func setSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let subscriptionValues: SubscriptionValues = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionValues")
            return nil
        }

        AccountManager().exchangeTokensAndRefreshEntitlements(with: subscriptionValues.token)
        return nil
    }

    func backToSettings(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .subscriptionPageCloseAndOpenPreferences, object: self)
        }

        return nil
    }

    func getSubscriptionOptions(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        struct SubscriptionOptions: Encodable {
            let platform: String
            let options: [SubscriptionOption]
            let features: [SubscriptionFeature]
        }

        struct SubscriptionOption: Encodable {
            let id: String
            let cost: SubscriptionCost

            struct SubscriptionCost: Encodable {
                let displayPrice: String
                let recurrence: String
            }
        }

        enum SubscriptionFeatureName: String, CaseIterable {
            case privateBrowsing = "private-browsing"
            case privateSearch = "private-search"
            case emailProtection = "email-protection"
            case appTrackingProtection = "app-tracking-protection"
            case vpn = "vpn"
            case personalInformationRemoval = "personal-information-removal"
            case identityTheftRestoration = "identity-theft-restoration"
        }

        struct SubscriptionFeature: Encodable {
            let name: String
        }

        let subscriptionOptions = [SubscriptionOption(id: "bundle_1", cost: .init(displayPrice: "$9.99", recurrence: "monthly")),
                                   SubscriptionOption(id: "bundle_2", cost: .init(displayPrice: "$99.99", recurrence: "yearly"))]

        let message = SubscriptionOptions(platform: "macos",
                                          options: subscriptionOptions,
                                          features: SubscriptionFeatureName.allCases.map { SubscriptionFeature(name: $0.rawValue) })

        return message
    }

    func subscriptionSelected(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        struct SubscriptionSelection: Decodable {
            let id: String
        }

        struct PurchaseUpdate: Codable {
            let type: String
        }

        let message = original

        guard let subscriptionSelection: SubscriptionSelection = DecodableHelper.decode(from: params) else {
            assertionFailure("SubscriptionPagesUserScript: expected JSON representation of SubscriptionSelection")
            return nil
        }

        print("Selected: \(subscriptionSelection.id)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let webview = message.webView else {
                print("No WebView")
                return
            }

//            self.broker?.push(method: "onPurchaseUpdate", params: PurchaseUpdate(type: "completed"), for: self, into: webview)

            print("Completed!")
            self.pushAction(method: .onPurchaseUpdate, webView: original.webView!, params: PurchaseUpdate(type: "completed"))

        }

        return nil
    }

    func activateSubscription(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        print(">>> Selected to activate a subscription -- show the activation settings screen")
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
    
    enum SubscribeActionName: String {
        case onPurchaseUpdate
    }

    func pushAction(method: SubscribeActionName, webView: WKWebView, params: Encodable) {
        let broker = UserScriptMessageBroker(context: SubscriptionPagesUserScript.context, requiresRunInPageContentWorld: true )

        print(">>> Pushing into WebView:", method.rawValue, String(describing: params))
        broker.push(method: method.rawValue, params: params, for: self, into: webView)
    }

}

#endif
