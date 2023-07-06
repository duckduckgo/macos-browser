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
    let configurationURLProvider: ConfigurationURLProviding

    init(configurationURLProvider: ConfigurationURLProviding) {
        self.configurationURLProvider = configurationURLProvider
    }

    // MARK: - Subfeature

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames

    enum MessageNames: String, CaseIterable {
        case getFeatures
        case updateResource
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch MessageNames(rawValue: methodName) {
        case .getFeatures:
            return handleGetFeatures
        case .updateResource:
            return handleUpdateResource
        default:
            assertionFailure("PrivacyConfigurationEditUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    @MainActor
    func handleGetFeatures(params: Any, message: UserScriptMessage) -> Encodable? {
        generateFeaturesResponse()
    }

    @MainActor
    func handleUpdateResource(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let request: UpdateResourceRequest = DecodableHelper.decode(from: params) else {
            assertionFailure("PrivacyConfigurationEditUserScript: expected JSON representation of UpdateResourceRequest")
            return nil
        }

        switch request.source {
        case let .remote(url):
            configurationURLProvider.setURL(url.url, for: .privacyConfiguration)
            ConfigurationManager.shared.forceRefresh()
            return generateFeaturesResponse()
        case let .debugTools(content):
            let result = ContentBlocking.shared.privacyConfigurationManager.override(with: content.utf8data)
            if result == .downloaded {
                return generateFeaturesResponse()
            }
        }
        return nil
    }

    private let dateFormatter = ISO8601DateFormatter()

    func generateFeaturesResponse() -> FeaturesResponse {
        let privacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager

        let source: RemoteResource.Source = {
            if let date = privacyConfigurationManager.overriddenAt {
                return .debugTools(modifiedAt: dateFormatter.string(from: date))
            }
            return .remote(
                url: AppConfigurationURLProvider().url(for: .privacyConfiguration).absoluteString,
                fetchedAt: dateFormatter.string(from: Date())
            )
        }()

        let resource = RemoteResource(
            id: "privacy-configuration",
            url: AppConfigurationURLProvider().url(for: .privacyConfiguration).absoluteString,
            name: "Privacy Config",
            current: .init(
                source: source,
                contents: privacyConfigurationManager.currentConfig.utf8String() ?? "",
                contentType: "application/json"
            )
        )

        return FeaturesResponse(features: .init(remoteResources: .init(resources: [resource])))
    }
}

// MARK: - UpdateResource

struct UpdateResourceRequest: Decodable {
    let id: String
    let source: Source

    enum Source: Decodable {
        case remote(url: String)
        case debugTools(content: String)
    }

    var url: URL? {
        switch source {
        case let .remote(url):
            return url.url
        default:
            return nil
        }
    }

    var content: String? {
        switch source {
        case let .debugTools(content):
            return content
        default:
            return nil
        }
    }
}

// MARK: - Features Response

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
