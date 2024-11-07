//
//  AIChatUserScript.swift
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

import Common
import UserScript

final class AIChatUserScript: NSObject, Subfeature {

    enum MessageNames: String, CaseIterable {
        case openSettings
        case getUserValues
    }

    private let handler: AIChatUserScriptHandling
    public let featureName: String = "aiChat"
    var broker: UserScriptMessageBroker?
    public let messageOriginPolicy: MessageOriginPolicy = .only(rules: [.exact(hostname: URL.duckDuckGo.absoluteString)])

    init(handler: AIChatUserScriptHandling) {
        self.handler = handler
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch MessageNames(rawValue: methodName) {
        case .getUserValues:
            return handler.handleGetUserValues
        case .openSettings:
            handler.openSettings()
            return nil
        default:
            return nil
        }
    }
}
