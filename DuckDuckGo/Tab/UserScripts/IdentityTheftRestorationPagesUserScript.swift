//
//  IdentityTheftRestorationPagesUserScript.swift
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

import BrowserServicesKit
import Common
import Combine
import Foundation
import WebKit
import Subscription
import UserScript

///
/// The user script that will be the broker for all subscription features
///
public final class IdentityTheftRestorationPagesUserScript: NSObject, UserScript, UserScriptMessaging {
    public var source: String = ""

    public static let context = "identityTheftRestorationPages"

    // special pages messaging cannot be isolated as we'll want regular page-scripts to be able to communicate
    public let broker = UserScriptMessageBroker(context: IdentityTheftRestorationPagesUserScript.context, requiresRunInPageContentWorld: true )

    public let messageNames: [String] = [
        IdentityTheftRestorationPagesUserScript.context
    ]

    public let injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public let forMainFrameOnly = true
    public let requiresRunInPageContentWorld = true
}

extension IdentityTheftRestorationPagesUserScript: WKScriptMessageHandlerWithReply {
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
extension IdentityTheftRestorationPagesUserScript: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // unsupported
    }
}

///
/// Use Subscription sub-feature
///
final class IdentityTheftRestorationPagesFeature: Subfeature {
    weak var broker: UserScriptMessageBroker?
    private let subscriptionFeatureAvailability: SubscriptionFeatureAvailability

    var featureName = "useIdentityTheftRestoration"

    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [
        .exact(hostname: "duckduckgo.com"),
        .exact(hostname: "abrown.duckduckgo.com")
    ])

    init(subscriptionFeatureAvailability: SubscriptionFeatureAvailability = DefaultSubscriptionFeatureAvailability()) {
        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
    }

    func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch methodName {
        case "getAccessToken": return getAccessToken
        case "getFeatureConfig": return getFeatureConfig
        case "openSendFeedbackModal": return openSendFeedbackModal
        default:
            return nil
        }
    }

    func getAccessToken(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if let accessToken = await Application.appDelegate.subscriptionManager.accountManager.accessToken {
            return ["token": accessToken]
        } else {
            return [String: String]()
        }
    }

    func getFeatureConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        [PrivacyProSubfeature.useUnifiedFeedback.rawValue: subscriptionFeatureAvailability.usesUnifiedFeedbackForm]
    }

    func openSendFeedbackModal(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        NotificationCenter.default.post(name: .OpenUnifiedFeedbackForm, object: nil, userInfo: UnifiedFeedbackSource.userInfo(source: .itr))
        return nil
    }
}
