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
    private var operationLog: OperationLog!
    private var configManager: ConfigurationManager!
    private var mockFetcher: MockConfigurationFetcher!
    private var mockStore: MockConfigurationStore!
    private var mockTrackerDataManager: MockTrackerDataManager!
    private var mockPrivacyConfigManager: MockPrivacyConfigurationManager!
    private var mockContentBlockingManager: MockContentBlockerRulesManager!

    override func setUpWithError() throws {
        operationLog = OperationLog()
        let userDefaults = UserDefaults(suiteName: "ConfigurationManagerTests")!
        userDefaults.removePersistentDomain(forName: "ConfigurationManagerTests")
        mockFetcher = MockConfigurationFetcher(operationLog: operationLog)
        mockStore = MockConfigurationStore()
        mockPrivacyConfigManager = MockPrivacyConfigurationManager(operationLog: operationLog, fetchedETag: nil, fetchedData: nil, embeddedDataProvider: MockEmbeddedDataProvider(), localProtection: MockDomainsProtectionStore(), internalUserDecider: DefaultInternalUserDecider())
        mockPrivacyConfigManager.operationLog = operationLog
        mockTrackerDataManager = MockTrackerDataManager(operationLog: operationLog, etag: nil, data: nil, embeddedDataProvider: MockEmbeddedDataProvider())
        mockContentBlockingManager = MockContentBlockerRulesManager(operationLog: operationLog)
        configManager = ConfigurationManager(fetcher: mockFetcher,
                                             store: mockStore, defaults: userDefaults,
                                             trackerDataManager: mockTrackerDataManager,
                                             privacyConfigurationManager: mockPrivacyConfigManager,
                                             contentBlockingManager: mockContentBlockingManager)
    }

    override func tearDownWithError() throws {
        operationLog = nil
        configManager = nil
        mockStore = nil
        mockFetcher = nil
        mockTrackerDataManager = nil
        mockPrivacyConfigManager = nil
        mockContentBlockingManager = nil
    }

    func test_WhenRefreshNow_AndPrivacyConfigFetchFails_OtherFetchStillHappen() async {
        // GIVEN
        mockFetcher.shouldFailPrivacyFetch = true
        operationLog.steps = []
        let expectedFirstTwo: Set<ConfigurationStep> = [.fetchPrivacyConfigStarted, .fetchSurrogatesStarted]
        let expectedOrder: [ConfigurationStep] = [
            .fetchTrackerDataSetStarted,
            .reloadTrackerDataSet,
            .reloadPrivacyConfig,
            .contentBlockingScheduleCompilation
        ]

        // WHEN
        await configManager.refreshNow(isDebug: false)

        // THEN
        XCTAssertEqual(Set(operationLog.steps.prefix(2)), expectedFirstTwo, "Steps do not match the expected order.")
        XCTAssertEqual(Array(operationLog.steps.dropFirst(2)), expectedOrder, "Steps do not match the expected order.")
    }

    func test_WhenRefreshNow_ThenPrivacyConfigFetchAndReloadBeforeTrackerDataSetFetch() async {
        // GIVEN
        operationLog.steps = []
        let expectedFirstTwo: Set<ConfigurationStep> = [.fetchPrivacyConfigStarted, .fetchSurrogatesStarted]
        let expectedOrder: [ConfigurationStep] = [
            .reloadPrivacyConfig,
            .fetchTrackerDataSetStarted,
            .reloadTrackerDataSet,
            .reloadPrivacyConfig,
            .contentBlockingScheduleCompilation
        ]

        // WHEN
        await configManager.refreshNow(isDebug: false)

        // THEN
        XCTAssertEqual(Set(operationLog.steps.prefix(2)), expectedFirstTwo, "Steps do not match the expected order.")
        XCTAssertEqual(Array(operationLog.steps.dropFirst(2)), expectedOrder, "Steps do not match the expected order.")
    }

}

// Step enum to track operations
private enum ConfigurationStep: String, Equatable {
    case fetchSurrogatesStarted
    case fetchPrivacyConfigStarted
    case fetchTrackerDataSetStarted
    case reloadPrivacyConfig
    case reloadTrackerDataSet
    case contentBlockingScheduleCompilation
}

private class MockConfigurationFetcher: ConfigurationFetching {
    var operationLog: OperationLog
    var shouldFailPrivacyFetch = false

    init(operationLog: OperationLog) {
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
            operationLog.steps.append(.fetchPrivacyConfigStarted)
            if shouldFailPrivacyFetch {
                throw NSError(domain: "TestError", code: 1, userInfo: nil)
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        case .surrogates:
            operationLog.steps.append(.fetchSurrogatesStarted)
        case .trackerDataSet:
            operationLog.steps.append(.fetchTrackerDataSetStarted)
        case .remoteMessagingConfig:
            break
        }
    }

    func fetch(all configurations: [Configuration]) async throws {}
}

private class MockPrivacyConfigurationManager: PrivacyConfigurationManager {
    var operationLog: OperationLog

    init(operationLog: OperationLog, fetchedETag: String?, fetchedData: Data?, embeddedDataProvider: any EmbeddedDataProvider, localProtection: any DomainsProtectionStore, internalUserDecider: any InternalUserDecider) {
        self.operationLog = operationLog
        super.init(fetchedETag: fetchedETag, fetchedData: fetchedData, embeddedDataProvider: embeddedDataProvider, localProtection: localProtection, internalUserDecider: internalUserDecider)
    }

    override func reload(etag: String?, data: Data?) -> ReloadResult {
        operationLog.steps.append(.reloadPrivacyConfig)
        return .embedded
    }
}

private class MockTrackerDataManager: TrackerDataManager {
    var operationLog: OperationLog

    init(operationLog: OperationLog, etag: String?, data: Data?, embeddedDataProvider: any EmbeddedDataProvider) {
        self.operationLog = operationLog
        super.init(etag: etag, data: data, embeddedDataProvider: embeddedDataProvider)
    }

    public override func reload(etag: String?, data: Data?) -> ReloadResult {
        operationLog.steps.append(.reloadTrackerDataSet)
        return .embedded
    }
}

private class MockContentBlockerRulesManager: ContentBlockerRulesManagerProtocol {
    var operationLog: OperationLog

    init(operationLog: OperationLog) {
        self.operationLog = operationLog
    }

    var updatesPublisher: AnyPublisher<ContentBlockerRulesManager.UpdateEvent, Never> = Empty<ContentBlockerRulesManager.UpdateEvent, Never>().eraseToAnyPublisher()

    var currentRules: [ContentBlockerRulesManager.Rules] = []

    func scheduleCompilation() -> ContentBlockerRulesManager.CompletionToken {
        operationLog.steps.append(.contentBlockingScheduleCompilation)
        return ""
    }

    var currentMainRules: ContentBlockerRulesManager.Rules?

    var currentAttributionRules: BrowserServicesKit.ContentBlockerRulesManager.Rules?

    func entity(forHost host: String) -> Entity? {
        return nil
    }

    func scheduleCompilation() {}
}

private class OperationLog {
    var steps: [ConfigurationStep] = []
}
