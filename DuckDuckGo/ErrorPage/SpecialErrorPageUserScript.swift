//
//  SpecialErrorPageUserScript.swift
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

protocol SpecialErrorPageUserScriptDelegate: AnyObject {
    var errorData: SpecialErrorData? { get }
    func leaveSite()
    func visitSite()
}

final class SpecialErrorPageUserScript: NSObject, Subfeature {
    enum MessageName: String, CaseIterable {
        case initialSetup
        case reportPageException
        case reportInitException
        case leaveSite
        case visitSite
    }

    public let messageOriginPolicy: MessageOriginPolicy = .all
    public let featureName: String = "special-error"

    var isEnabled: Bool = false
    var failingURL: URL?

    weak var broker: UserScriptMessageBroker?
    weak var delegate: SpecialErrorPageUserScriptDelegate?

    func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    @MainActor
    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        guard isEnabled else { return nil }
        guard let messageName = MessageName(rawValue: methodName) else { return nil }
        return methodHandlers[messageName]
    }

    private lazy var methodHandlers: [MessageName: Handler] = [
           .initialSetup: initialSetup,
           .reportPageException: reportPageException,
           .reportInitException: reportInitException,
           .leaveSite: handleLeaveSiteAction,
           .visitSite: handleVisitSiteAction
       ]

    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
#if DEBUG
        let env = "development"
#else
        let env = "production"
#endif
        let platform = Platform(name: "macos")
        guard let errorData = delegate?.errorData else { return nil }
        return InitialSetupResult(env: env, locale: Locale.current.identifier, platform: platform, errorData: errorData)
    }

    @MainActor
    func handleLeaveSiteAction(params: Any, message: UserScriptMessage) -> Encodable? {
        delegate?.leaveSite()
        return nil
    }

    @MainActor
    func handleVisitSiteAction(params: Any, message: UserScriptMessage) -> Encodable? {
        delegate?.visitSite()
        return nil
    }

    @MainActor
     private func reportInitException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
         return nil
     }

    @MainActor
     private func reportPageException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
         return nil
     }

    // MARK: - UserValuesNotification

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues
    }
}

// MARK: - Structures
extension SpecialErrorPageUserScript {
    struct Platform: Encodable, Equatable {
        let name: String
    }

    struct InitialSetupResult: Encodable, Equatable {
        let env: String
        let locale: String
        let platform: Platform
        let errorData: SpecialErrorData
    }
}
