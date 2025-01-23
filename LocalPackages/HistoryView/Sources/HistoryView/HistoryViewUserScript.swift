//
//  HistoryViewUserScript.swift
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

import Foundation
import UserScriptActionsManager
import WebKit

public final class HistoryViewUserScript: NSObject, SubfeatureWithExternalMessageHandling {

    public var messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: "history")])
    public let featureName: String = "history"
    public weak var broker: UserScriptMessageBroker?

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - Message Handling

    public typealias MessageName = String

    public weak var webView: WKWebView?
    private var messageHandlers: [MessageName: Handler] = [:]

    public func registerMessageHandlers(_ handlers: [MessageName: Subfeature.Handler]) {
        messageHandlers.merge(handlers, uniquingKeysWith: { $1 })
    }

    public func handler(forMethodNamed methodName: MessageName) -> Handler? {
        messageHandlers[methodName]
    }

    func pushMessage(named method: MessageName, params: Encodable?, using script: HistoryViewUserScript) {
        guard let webView = script.webView else {
            return
        }
        script.broker?.push(method: method, params: params, for: script, into: webView)
    }
}
