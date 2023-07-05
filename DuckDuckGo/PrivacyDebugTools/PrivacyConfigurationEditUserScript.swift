//
//  PrivacyConfigurationEditUserScript.swift
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

import BrowserServicesKit
import Configuration
import WebKit
import Common
import UserScript

final class PrivacyConfigurationEditUserScript: NSObject, Subfeature {

    let messageOriginPolicy: MessageOriginPolicy = .all
    let featureName: String = "debugToolsPage"
    var broker: UserScriptMessageBroker?

    // MARK: - Subfeature

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames

    enum MessageNames: String, CaseIterable {
        case getFeatures
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch MessageNames(rawValue: methodName) {
        case .getFeatures:
            return handleGetFeatures
        default:
            assertionFailure("PrivacyConfigurationEditUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    @MainActor
    func handleGetFeatures(params: Any, message: UserScriptMessage) -> Encodable? {
        print(message.messageName)
        let privacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager

        let dateFormatter = ISO8601DateFormatter()

        let resource = RemoteResource(
            id: "privacy-configuration",
            url: AppConfigurationURLProvider().url(for: .privacyConfiguration).absoluteString,
            name: "Privacy Config",
            current: .init(
                source: .remote(
                    url: AppConfigurationURLProvider().url(for: .privacyConfiguration).absoluteString,
                    fetchedAt: dateFormatter.string(from: Date())
                ),
                contents: privacyConfigurationManager.currentConfig.utf8String() ?? "",
                contentType: "application/json"
            )
        )

        return FeaturesResponse(features: .init(remoteResources: .init(resources: [resource])))
    }
}

struct FeaturesResponse: Codable {
    let features: Features
}

struct Features: Codable {
    let remoteResources: RemoteResources
}

struct RemoteResources: Codable {
    let resources: [RemoteResource]
}

struct RemoteResource: Codable {
    let id: String
    let url: String
    let name: String
    let current: Current

    struct Current: Codable {
        let source: Source
        let contents: String
        let contentType: String
    }

    enum Source: Codable {
        case remote(url: String, fetchedAt: String)
        case debugTools(modifiedAt: String)
    }
}
