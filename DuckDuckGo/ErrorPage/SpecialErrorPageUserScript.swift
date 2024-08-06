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

final class SpecialErrorPageUserScript: NSObject, Subfeature {
    struct InitialSetupParameters {
        let kind: String
        let errorType: String?
        let domain: String?

        static func from(params: Any) -> Self? {
            guard let dict = params as? [String: Any] else {
                return nil
            }

            let kind = dict["kind"] as? String ?? ""
            let errorType = dict["errorType"] as? String
            let domain = dict["domain"] as? String

            return InitialSetupParameters(kind: kind, errorType: errorType, domain: domain)
        }
    }

    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
#if DEBUG
        let env = "development"
#else
        let env = "production"
#endif
        if let initialSetupParameters = InitialSetupParameters.from(params: params) {
            let platform = Platform(name: "macos")
            let errorData = ErrorData(kind: initialSetupParameters.kind, errorType: initialSetupParameters.errorType, domain: initialSetupParameters.domain)
            return InitialSetupResult(env: env, locale: Locale.current.identifier, platform: platform, errorData: errorData)
        } else {
            print("[-] Unable to decode initial setup params in SpecialErrorPage")
        }
        return nil
    }

    struct Platform: Encodable {
        let name: String
    }

    struct ErrorData: Encodable {
        let kind: String
        let errorType: String?
        let domain: String?
    }

    struct InitialSetupResult: Encodable {
        let env: String
        let locale: String
        let platform: Platform
        let errorData: ErrorData
    }

    @MainActor
    private func reportPageException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return nil
    }

    @MainActor
    private func reportInitException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return nil
    }

    enum MessageNames: String, CaseIterable {
        case initialSetup
        case reportPageException
        case reportInitException
        case leaveSite
        case visitSite
    }

    public let messageOriginPolicy: MessageOriginPolicy = .all
    public let featureName: String = "specialErrorPage"

    var isEnabled: Bool = false
    var failingURL: URL?

    weak var broker: UserScriptMessageBroker?
    weak var delegate: SpecialErrorPageUserScriptDelegate?

    func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    private lazy var methodHandlers: [MessageNames: Handler] = [
        .initialSetup: initialSetup,
        .reportPageException: reportPageException,
        .reportInitException: reportInitException,
        .leaveSite: handleLeaveSiteAction,
        .visitSite: handleVisitSiteAction
    ]

    @MainActor
    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let messageName = MessageNames(rawValue: methodName) else { return nil }
        return methodHandlers[messageName]
    }

    @MainActor
    func handleLeaveSiteAction(params: Any, message: WKScriptMessage) -> Encodable? {
        delegate?.leaveSite()
        return nil
    }

    @MainActor
    func handleVisitSiteAction(params: Any, message: WKScriptMessage) -> Encodable? {
        delegate?.visitSite()
        return nil
    }

    // MARK: - UserValuesNotification

    struct UserValuesNotification: Encodable {
        let userValuesNotification: UserValues
    }
}

protocol SpecialErrorPageUserScriptDelegate: AnyObject {
    func leaveSite()
    func visitSite()
}
