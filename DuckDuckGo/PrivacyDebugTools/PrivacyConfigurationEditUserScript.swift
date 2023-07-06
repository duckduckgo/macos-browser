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
    func handleUpdateResource(params: Any, message: UserScriptMessage) async throws -> Encodable? {
        guard let request: UpdateResourceRequest = DecodableHelper.decode(from: params) else {
            assertionFailure("PrivacyConfigurationEditUserScript: expected JSON representation of UpdateResourceRequest")
            return nil
        }

        switch request.source {
        case let .remote(url):
            configurationURLProvider.setURL(url.url, for: .privacyConfiguration)
            try await ConfigurationManager.shared.forceRefresh(.privacyConfiguration)
            return generateResourceResponse()
        case let .debugTools(content):
            let result = ContentBlocking.shared.privacyConfigurationManager.override(with: content.utf8data)
            if result != .downloaded {
                throw UpdateResourceError(message: "Failed to parse custom Privacy Config")
            }
            return generateResourceResponse()
        }
    }

    private let dateFormatter = ISO8601DateFormatter()

    @MainActor
    func generateResourceResponse() -> RemoteResource {
        let privacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager
        // swiftlint:disable:next force_cast
        let urlProvider = (NSApp.delegate as! AppDelegate).configurationURLProvider

        let source: RemoteResource.Source = {
            if let date = privacyConfigurationManager.overriddenAt {
                return .debugTools(modifiedAt: dateFormatter.string(from: date))
            }
            return .remote(
                url: urlProvider.url(for: .privacyConfiguration).absoluteString,
                fetchedAt: dateFormatter.string(from: Date())
            )
        }()

        return RemoteResource(
            id: "privacy-configuration",
            url: urlProvider.url(for: .privacyConfiguration).absoluteString,
            name: "Privacy Config",
            current: .init(
                source: source,
                contents: privacyConfigurationManager.currentConfig.utf8String() ?? "",
                contentType: "application/json"
            )
        )
    }

    @MainActor
    func generateFeaturesResponse() -> FeaturesResponse {
        return FeaturesResponse(features: .init(remoteResources: .init(resources: [generateResourceResponse()])))
    }
}

struct UpdateResourceError: Error {
    let message: String
}

// MARK: - UpdateResource

struct UpdateResourceRequest: Decodable {
    let id: String
    let source: Source

    enum Source: Decodable {
        case remote(url: String)
        case debugTools(content: String)
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
