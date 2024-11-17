//
//  NewTabPageUserScript.swift
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
import UserScript
import WebKit

protocol SubfeatureWithExternalMessageHandling: AnyObject, Subfeature {
    var webView: WKWebView? { get }
    func registerMessageHandlers(_ handlers: [String: Subfeature.Handler])
}

final class NewTabPageUserScript: NSObject, SubfeatureWithExternalMessageHandling {

    let actionsManager: NewTabPageActionsManaging
    var messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: "newtab")])
    let featureName: String = "newTabPage"
    weak var broker: UserScriptMessageBroker?
    weak var webView: WKWebView?
    private var methodHandlers: [MessageName: Handler] = [:]

    // MARK: - MessageNames

    typealias MessageName = String

    init(actionsManager: NewTabPageActionsManaging) {
        self.actionsManager = actionsManager
        super.init()
        actionsManager.registerUserScript(self)
    }

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    func registerMessageHandlers(_ handlers: [MessageName: Subfeature.Handler]) {
        for (messageName, handler) in handlers {
            methodHandlers[messageName] = handler
        }
    }

    func handler(forMethodNamed methodName: MessageName) -> Handler? {
        methodHandlers[methodName]
    }

    func pushMessage(named method: String, params: Encodable?, using script: NewTabPageUserScript) {
        guard let webView = script.webView else {
            return
        }
        script.broker?.push(method: method, params: params, for: script, into: webView)
    }
}

extension NewTabPageUserScript {

    struct WidgetConfig: Encodable {
        let animation: Animation?
        let expansion: Expansion
    }

    enum Expansion: String, Encodable {
        case collapsed, expanded
    }

    struct Animation: Encodable {
        let kind: AnimationKind

        static let none = Animation(kind: .none)
        static let viewTransitions = Animation(kind: .viewTransitions)
        static let auto = Animation(kind: .auto)

        enum AnimationKind: String, Encodable {
            case none
            case viewTransitions = "view-transitions"
            case auto = "auto-animate"
        }
    }
}
