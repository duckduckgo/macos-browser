//
//  DataBrokerMessaging.swift
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
import UserScript
import WebKit

struct DataBrokerMessaging: UserScriptMessagingSubFeature {

    let webView: WKWebView? = nil

    func handlerFor(_ method: String) -> Handler? {
        switch method {
        case "getAction": return getAction
        case "ready": return ready
        default: return nil
        }
    }

    struct Person: Decodable {
        let name: String
    }

    struct Person2: Encodable {
        let name: String
    }

    func getAction(params: Any, original: WKScriptMessage, replyHandler: @escaping MessageReplyHandler) throws {
        guard let p: Person = DecodableHelper.decode(from: params) else {
            assertionFailure("oops")
            return
        }

        replyHandler(Person2(name: "shane"))
    }

    func actionComplete(params: Any, original: WKScriptMessage, replyHandler: @escaping MessageReplyHandler) throws {
        guard let p: Person = DecodableHelper.decode(from: params) else {
            assertionFailure("oops")
            return
        }

        replyHandler(Person2(name: "shane"))
    }

    func ready(params: Any, original: WKScriptMessage, replyHandler: @escaping MessageReplyHandler) throws {
        print("READY")
        //self.ready = true
        //self.next()
    }

    @MainActor
    func sendAction(action: Encodable) {
        if let subscriptionEvent = SubscriptionEvent.toJS(
            context: "contentScopeScripts",
            featureName: featureName,
            subscriptionName: "onActionReceived",
            params: action
        ) {
            webView?.evaluateJavaScript(subscriptionEvent)
        }
    }

    var allowedOrigins: AllowedOrigins = .all

    var featureName: String = "brokerProtection"

}
