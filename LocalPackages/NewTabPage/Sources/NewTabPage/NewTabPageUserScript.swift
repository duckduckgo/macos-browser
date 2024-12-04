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

/**
 * This protocol extends `Subfeature` and allows to register message handlers from an external source.
 *
 * `NewTabPageUserScript` manages many different features that only share the same view
 * (HTML New Tab Page) and are otherwise independent of each other.
 *
 * Implementing this protocol in `NewTabPageUserScript` allows for having multiple objects
 * registered as handlers to handle feature-specific messages, e.g. a separate object
 * responsible for RMF, favorites, privacy stats, etc.
 */
public protocol SubfeatureWithExternalMessageHandling: AnyObject, Subfeature {
    var webView: WKWebView? { get }
    func registerMessageHandlers(_ handlers: [String: Subfeature.Handler])
}

public final class NewTabPageUserScript: NSObject, SubfeatureWithExternalMessageHandling {

    public var messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: "newtab")])
    public let featureName: String = "newTabPage"
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

    public func pushMessage(named method: String, params: Encodable?, using script: NewTabPageUserScript) {
        guard let webView = script.webView else {
            return
        }
        script.broker?.push(method: method, params: params, for: script, into: webView)
    }
}

public extension NewTabPageUserScript {

    public struct WidgetConfig: Codable {
        public let animation: Animation?
        public let expansion: Expansion

        public init(animation: Animation?, expansion: Expansion) {
            self.animation = animation
            self.expansion = expansion
        }

        public enum Expansion: String, Codable {
            case collapsed, expanded
        }

        public struct Animation: Codable, Equatable {
            public let kind: AnimationKind

            public init(kind: AnimationKind) {
                self.kind = kind
            }

            public static let none = Animation(kind: .none)
            public static let viewTransitions = Animation(kind: .viewTransitions)
            public static let auto = Animation(kind: .auto)

            public enum AnimationKind: String, Codable {
                case none
                case viewTransitions = "view-transitions"
                case auto = "auto-animate"
            }
        }
    }
}
