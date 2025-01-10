//
//  ConfigurationManagerTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import XCTest
import Configuration
@testable import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser
import Combine
import TrackerRadarKit

final class ConfigurationManagerTests: XCTestCase {
    private var operationLog: [ConfigurationStep] = []
    private var sut: ConfigurationManager!
    private var mockFetcher: MockConfigurationFetcher!
    private var mockStore: MockConfigurationStore!
    private var mockTrackerDataManager: MockTrackerDataManager!
    private var mockPrivacyConfigManager: MockPrivacyConfigurationManager!
    private var mockContentBlockingManager: MockContentBlockerRulesManager!

    override func setUpWithError() throws {
        let userDefaults = UserDefaults(suiteName: "ConfigurationManagerTests")!
        userDefaults.removePersistentDomain(forName: "ConfigurationManagerTests")
        mockFetcher = MockConfigurationFetcher(operationLog: &operationLog)
        mockPrivacyConfigManager = MockPrivacyConfigurationManager(fetchedETag: nil, fetchedData: nil, embeddedDataProvider: MockEmbeddedDataProvider(), localProtection: MockDomainsProtectionStore(), internalUserDecider: DefaultInternalUserDecider())
        mockPrivacyConfigManager.operationLog = operationLog
        mockTrackerDataManager = MockTrackerDataManager(etag: nil, data: nil, embeddedDataProvider: MockEmbeddedDataProvider())
        mockContentBlockingManager = MockContentBlockerRulesManager()
        sut = ConfigurationManager(fetcher: mockFetcher, store: mockStore, defaults: userDefaults)
        sut.setContentBlockingManagers(
            trackerDataManager: mockTrackerDataManager,
            privacyConfigurationManager: mockPrivacyConfigManager,
            contentBlockingManager: mockContentBlockingManager
        )
    }

    override func tearDownWithError() throws {
        operationLog = []
        sut = nil
        mockStore = nil
        mockFetcher = nil
        mockTrackerDataManager = nil
        mockPrivacyConfigManager = nil
        mockContentBlockingManager = nil
    }

    func testPrivacyConfigFetchAndReloadBeforeTrackerDataSetFetch() async {
        // GIVEN
        let expectedOrder: [ConfigurationStep] = [
            .fetchSurrogates,
            .fetchPrivacyConfig,
            .reloadPrivacyConfig,
            .fetchTrackerDataSet
        ]

        // WHEN
        await sut.refreshNow(isDebug: false)

        XCTAssertEqual(operationLog, expectedOrder, "Operations did not occur in the expected order.")
    }

}

// Step enum to track operations
private enum ConfigurationStep: String, Equatable {
    case fetchSurrogates
    case fetchPrivacyConfig
    case reloadPrivacyConfig
    case fetchTrackerDataSet
}

private class MockConfigurationFetcher: ConfigurationFetching {
    var operationLog: [ConfigurationStep]
    var shouldFailPrivacyFetch = false
    var shouldFailSurrogatesFetch = false
    var shouldFailTdsFetch = false

    init(operationLog: inout [ConfigurationStep]) {
        self.operationLog = operationLog
    }

    func fetch(_ configuration: Configuration, isDebug: Bool) async throws {
        switch configuration {
        case .bloomFilterBinary:
            break
        case .bloomFilterSpec:
            break
        case .bloomFilterExcludedDomains:
            break
        case .privacyConfiguration:
            operationLog.append(.fetchPrivacyConfig)
            if shouldFailPrivacyFetch {
                throw NSError(domain: "TestError", code: 1, userInfo: nil)
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        case .surrogates:
            operationLog.append(.fetchTrackerDataSet)
            if shouldFailSurrogatesFetch {
                throw NSError(domain: "TestError", code: 1, userInfo: nil)
            }
        case .trackerDataSet:
            operationLog.append(.fetchTrackerDataSet)
            if shouldFailTdsFetch {
                throw NSError(domain: "TestError", code: 1, userInfo: nil)
            }
        case .remoteMessagingConfig:
            break
        }
    }

    func fetch(all configurations: [Configuration]) async throws {}
}

private class MockPrivacyConfigurationManager: PrivacyConfigurationManager {
    var operationLog: [ConfigurationStep] = []

    override func reload(etag: String?, data: Data?) -> ReloadResult {
        operationLog.append(.reloadPrivacyConfig)
        return .embedded
    }
}

class MockTrackerDataManager: TrackerDataManager {
    func reload(etag: String?, data: Data?) {}
}

class MockContentBlockerRulesManager: ContentBlockerRulesManagerProtocol {
    var updatesPublisher: AnyPublisher<ContentBlockerRulesManager.UpdateEvent, Never> = Empty<ContentBlockerRulesManager.UpdateEvent, Never>().eraseToAnyPublisher()

    var currentRules: [ContentBlockerRulesManager.Rules] = []

    func scheduleCompilation() -> ContentBlockerRulesManager.CompletionToken {
        return ""
    }

    var currentMainRules: ContentBlockerRulesManager.Rules?

    var currentAttributionRules: BrowserServicesKit.ContentBlockerRulesManager.Rules?

    func entity(forHost host: String) -> Entity? {
        return nil
    }

    func scheduleCompilation() {}
}
