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
import Combine
import Common
import UserScript
import ContentBlocking

final class PrivacyConfigurationEditUserScript: NSObject, Subfeature {
    let messageOriginPolicy: MessageOriginPolicy = .only(
        rules: [
            .exact(hostname: PrivacyDebugTools.urlHost),
            .exact(hostname: "localhost:3000"),
            .exact(hostname: "localhost:3210"),
        ]
    )
    let featureName: String = "debugToolsPage"
    weak var broker: UserScriptMessageBroker?
    weak var webView: WKWebView?

    weak var debugTools: PrivacyDebugTools? = nil {
        didSet {
            guard let debugTools = debugTools else { return }

            debugTools.itemsPublisher.sink { (trackers: [DetectedTracker]) in
                guard let current = debugTools.current else { return }
                self.publishTrackers(domain: current, trackers: trackers)
            }.store(in: &cancellables)
        }
    }

    let configurationURLProvider: ConfigurationURLProviding
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    var isActive: Bool = false {
        didSet {
            if isActive {
                if !oldValue {
                    openTabsURLsCancellable = subscribeToTabsURLs()
                }
            } else {
                openTabsURLsCancellable = nil
            }
        }
    }

    private var openTabsURLsCancellable: AnyCancellable?
    private weak var windowControllersManager: WindowControllersManager?

    @MainActor
    init(configurationURLProvider: ConfigurationURLProviding, windowControllersManager: WindowControllersManager = .shared) {
        self.configurationURLProvider = configurationURLProvider
        self.windowControllersManager = windowControllersManager
    }

    @MainActor
    private func subscribeToTabsURLs() -> AnyCancellable? {
        windowControllersManager?.$mainWindowControllers
            .flatMap { controllers -> AnyPublisher<[Tab], Never> in
                let tabsPublishers = controllers.map { $0.mainViewController.tabCollectionViewModel.tabCollection.$tabs.eraseToAnyPublisher() }
                return tabsPublishers.reduce(Just([Tab]()).eraseToAnyPublisher()) { partialResult, publisher -> AnyPublisher<[Tab], Never> in
                    partialResult.combineLatest(publisher, { $0 + $1 }).eraseToAnyPublisher()
                }
            }
            .flatMap { tabs -> AnyPublisher<[Tab.TabContent], Never> in
                let contentPublishers = tabs.map { $0.$content.eraseToAnyPublisher() }
                return contentPublishers.reduce(Just([Tab.TabContent]()).eraseToAnyPublisher()) { partialResult, publisher -> AnyPublisher<[Tab.TabContent], Never> in
                    partialResult.combineLatest(publisher, { $0 + [$1] }).eraseToAnyPublisher()
                }
            }
            .map { $0.compactMap(\.url).removingDuplicates(byKey: \.absoluteString).filter { $0.scheme != PrivacyDebugTools.urlHost } }
            .removeDuplicates()
            .sink { [weak self] urls in
                guard let self, let webView else {
                    return
                }
                print("Open tab URLs:")
                print(urls)
                self.broker?.push(method: "onTabsUpdated", params: GetTabsResponse(urls: urls), for: self, into: webView)
            }
    }

    struct SubscribeToTrackers: Decodable {
        let domain: String;
    }

    struct SubscribeToTrackersResponse: Encodable {
        let requests: [DetectedRequest];
    }

    @MainActor
    func handleSubscribeToTrackers(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let params: SubscribeToTrackers = DecodableHelper.decode(from: params),
              let tools = self.debugTools else {
            return nil
        }
        tools.setCurrent(domain: params.domain)
        return nil
    }

    @MainActor
    func handleUnsubscribeToTrackers(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let tools = self.debugTools else {
            return nil
        }
        tools.setCurrent(domain: nil)
        return nil
    }

    func publishTrackers(domain: String, trackers: [DetectedTracker]) {
        guard let webView = webView else {
            print("webview was absent");
            return
        }
        let response = SubscribeToTrackersResponse.init(requests: trackers.map { $0.request })
        self.broker?.push(method: "onTrackersUpdated", params: response, for: self, into: webView)
    }

    // MARK: - Subfeature

    public func with(broker: UserScriptMessageBroker) {
        self.broker = broker
    }

    // MARK: - MessageNames

    enum MessageNames: String, CaseIterable {
        case getTabs
        case getFeatures
        case updateResource
        case getRemoteResource
        case subscribeToTrackers
        case unsubscribeToTrackers
    }

    enum SupportedRemoteResources: String, CaseIterable {
        case privacyConfiguration = "privacy-configuration"
    }

    func handler(forMethodNamed methodName: String) -> Subfeature.Handler? {
        switch MessageNames(rawValue: methodName) {
        case .getTabs:
            return handleGetTabs
        case .getFeatures:
            return handleGetFeatures
        case .getRemoteResource:
            return handleGetRemoteResource
        case .updateResource:
            return handleUpdateResource
        case .subscribeToTrackers:
            return handleSubscribeToTrackers
        case .unsubscribeToTrackers:
            return handleUnsubscribeToTrackers;
        default:
            assertionFailure("PrivacyConfigurationEditUserScript: Failed to parse User Script message: \(methodName)")
            return nil
        }
    }

    @MainActor
    func handleGetTabs(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let windowControllersManager else {
            assertionFailure("windowControllersManager is nil")
            return nil
        }

        let urls = windowControllersManager.mainWindowControllers
            .map(\.mainViewController.tabCollectionViewModel.tabs)
            .flatMap { $0 }
            .compactMap(\.content.url)

        return GetTabsResponse.init(urls: urls.removingDuplicates(byKey: \.absoluteString).filter { $0.scheme != PrivacyDebugTools.urlHost })
    }

    @MainActor
    func handleGetFeatures(params: Any, message: UserScriptMessage) -> Encodable? {
        generateFeaturesResponse()
    }

    struct GetRemoteResourceParams: Decodable {
        let id: String;
    }

    @MainActor
    func handleGetRemoteResource(params: Any, message: UserScriptMessage) -> Encodable? {
        guard let params: GetRemoteResourceParams = DecodableHelper.decode(from: params),
              let supported = SupportedRemoteResources(rawValue: params.id) else {
            assertionFailure("PrivacyConfigurationEditUserScript: cannot provide resource")
            return nil
        }
        return generateResourceResponseFor(resource: supported)
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
            return generateResourceResponseFor(resource: .privacyConfiguration)
        case let .debugTools(content):
            try await ConfigurationManager.shared.override(.privacyConfiguration, with: content.utf8data)
            return generateResourceResponseFor(resource: .privacyConfiguration)
        }
    }

    private let dateFormatter = ISO8601DateFormatter()

    @MainActor
    func generateResourceRefsResponse() -> [RemoteResourceRef] {
        // swiftlint:disable:next force_cast
        let urlProvider = (NSApp.delegate as! AppDelegate).configurationURLProvider

        return [
            RemoteResourceRef(
                id: SupportedRemoteResources.privacyConfiguration.rawValue,
                url: urlProvider.url(for: .privacyConfiguration, allowOverrides: false).absoluteString,
                name: "Privacy Config"
            )
        ]
    }

    @MainActor
    func generateResourceResponseFor(resource: SupportedRemoteResources) -> RemoteResource {
        // unused `id`
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
            id: SupportedRemoteResources.privacyConfiguration.rawValue,
            url: urlProvider.url(for: .privacyConfiguration, allowOverrides: false).absoluteString,
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
        return FeaturesResponse(features: .init(remoteResources: .init(resources: generateResourceRefsResponse())))
    }
}

// MARK: - GetTabsResponse

struct GetTabsResponse: Encodable {
    let tabs: [TabResponse]

    init(urls: [URL]) {
        tabs = urls.map(TabResponse.init)
    }

    struct TabResponse: Encodable {
        let url: URL
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
}

// MARK: - Features Response

struct FeaturesResponse: Codable {
    let features: Features
}

struct Features: Codable {
    let remoteResources: RemoteResources
}

struct RemoteResources: Codable {
    let resources: [RemoteResourceRef]
}

struct RemoteResourceRef: Codable {
    let id: String
    let url: String
    let name: String
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
