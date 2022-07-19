//
//  ContentBlocking.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import WebKit
import Combine
import os.log
import BrowserServicesKit

final class ContentBlocking {
    static let shared = ContentBlocking()

    let privacyConfigurationManager: PrivacyConfigurationManager
    let trackerDataManager: TrackerDataManager
    let contentBlockingManager: ContentBlockerRulesManager
    let contentBlockingUpdating: ContentBlockingUpdating

    private let contentBlockerRulesSource: ContentBlockerRulesLists
    private let exceptionsSource: DefaultContentBlockerRulesExceptionsSource

    // keeping whole ContentBlocking state initialization in one place to avoid races between updates publishing and rules storing
    private init() {
        let configStorage = DefaultConfigurationStorage.shared
        privacyConfigurationManager = PrivacyConfigurationManager(fetchedETag: configStorage.loadEtag(for: .privacyConfiguration),
                                                                  fetchedData: configStorage.loadData(for: .privacyConfiguration),
                                                                  embeddedDataProvider: AppPrivacyConfigurationDataProvider(),
                                                                  localProtection: LocalUnprotectedDomains.shared,
                                                                  errorReporting: Self.debugEvents)

        trackerDataManager = TrackerDataManager(etag: DefaultConfigurationStorage.shared.loadEtag(for: .trackerRadar),
                                                data: DefaultConfigurationStorage.shared.loadData(for: .trackerRadar),
                                                embeddedDataProvider: AppTrackerDataSetProvider(),
                                                errorReporting: Self.debugEvents)

        contentBlockerRulesSource = ContentBlockerRulesLists(trackerDataManager: trackerDataManager)
        exceptionsSource = DefaultContentBlockerRulesExceptionsSource(privacyConfigManager: privacyConfigurationManager)

        contentBlockingManager = ContentBlockerRulesManager(rulesSource: contentBlockerRulesSource,
                                                            exceptionsSource: exceptionsSource,
                                                            cache: ContentBlockingRulesCache(),
                                                            errorReporting: Self.debugEvents,
                                                            logger: OSLog.contentBlocking)
        contentBlockingUpdating = ContentBlockingUpdating(contentBlockerRulesManager: contentBlockingManager,
                                                          privacyConfigurationManager: privacyConfigurationManager,
                                                          configStorage: configStorage)

    }

    private static let debugEvents = EventMapping<ContentBlockerDebugEvents> { event, scope, error, parameters, onComplete in
#if DEBUG
        guard !AppDelegate.isRunningTests else { return }
#endif

        let domainEvent: Pixel.Event.Debug
        switch event {
        case .trackerDataParseFailed:
            domainEvent = .trackerDataParseFailed

        case .trackerDataReloadFailed:
            domainEvent = .trackerDataReloadFailed

        case .trackerDataCouldNotBeLoaded:
            domainEvent = .trackerDataCouldNotBeLoaded

        case .privacyConfigurationReloadFailed:
            domainEvent = .privacyConfigurationReloadFailed

        case .privacyConfigurationParseFailed:
            domainEvent = .privacyConfigurationParseFailed

        case .privacyConfigurationCouldNotBeLoaded:
            domainEvent = .privacyConfigurationCouldNotBeLoaded

        case .contentBlockingTDSCompilationFailed:
            if scope == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName {
                domainEvent = .contentBlockingTDSCompilationFailed
            } else if scope == ContentBlockerRulesLists.Constants.clickToLoadRulesListName {
                domainEvent = .clickToLoadTDSCompilationFailed
            } else {
                domainEvent = .contentBlockingErrorReportingIssue
            }

        case .contentBlockingTempListCompilationFailed:
            if scope == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName {
                domainEvent = .contentBlockingTempListCompilationFailed
            } else if scope == ContentBlockerRulesLists.Constants.clickToLoadRulesListName {
                domainEvent = .clickToLoadTempListCompilationFailed
            } else {
                domainEvent = .contentBlockingErrorReportingIssue
            }

        case .contentBlockingAllowListCompilationFailed:
            if scope == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName {
                domainEvent = .contentBlockingAllowListCompilationFailed
            } else if scope == ContentBlockerRulesLists.Constants.clickToLoadRulesListName {
                domainEvent = .clickToLoadAllowListCompilationFailed
            } else {
                domainEvent = .contentBlockingErrorReportingIssue
            }

        case .contentBlockingUnpSitesCompilationFailed:
            if scope == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName {
                domainEvent = .contentBlockingUnpSitesCompilationFailed
            } else if scope == ContentBlockerRulesLists.Constants.clickToLoadRulesListName {
                domainEvent = .clickToLoadUnpSitesCompilationFailed
            } else {
                domainEvent = .contentBlockingErrorReportingIssue
            }

        case .contentBlockingFallbackCompilationFailed:
            if scope == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName {
                domainEvent = .contentBlockingFallbackCompilationFailed
            } else if scope == ContentBlockerRulesLists.Constants.clickToLoadRulesListName {
                domainEvent = .clickToLoadFallbackCompilationFailed
            } else {
                domainEvent = .contentBlockingErrorReportingIssue
            }

        case .contentBlockingCompilationTime:
            domainEvent = .contentBlockingCompilationTime
        }

        Pixel.fire(.debug(event: domainEvent, error: error), withAdditionalParameters: parameters, onComplete: onComplete)
    }
}

final class ContentBlockingUpdating {

    private struct BufferedValue {
        let rulesUpdate: ContentBlockerRulesManager.UpdateEvent
        let sourceProvider: ScriptSourceProviding

        init(rulesUpdate: ContentBlockerRulesManager.UpdateEvent, sourceProvider: ScriptSourceProviding) {
            self.rulesUpdate = rulesUpdate
            self.sourceProvider = sourceProvider
        }
    }

    @Published private var bufferedValue: BufferedValue?
    private var cancellable: AnyCancellable?

    private(set) var userContentBlockingAssets: AnyPublisher<UserContentController.ContentBlockingAssets, Never>!

    init(contentBlockerRulesManager: ContentBlockerRulesManagerProtocol,
         privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager,
         configStorage: ConfigurationStoring = DefaultConfigurationStorage.shared,
         privacySecurityPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared) {

        let makeValue: (ContentBlockerRulesManager.UpdateEvent) -> BufferedValue = { rulesUpdate in
            let sourceProvider = DefaultScriptSourceProvider(configStorage: configStorage,
                                                             privacyConfigurationManager: privacyConfigurationManager,
                                                             privacySettings: privacySecurityPreferences,
                                                             contentBlockingManager: contentBlockerRulesManager)
            return BufferedValue(rulesUpdate: rulesUpdate, sourceProvider: sourceProvider)
        }

        // 1. Collect updates from ContentBlockerRulesManager and generate UserScripts based on its output
        cancellable = contentBlockerRulesManager.updatesPublisher
            // regenerate UserScripts on gpcEnabled preference updated
            .combineLatest(privacySecurityPreferences.$gpcEnabled)
            .map { $0.0 } // drop gpcEnabled value: $0.1
            // DefaultScriptSourceProvider instance should be created once per rules/config change and fed into UserScripts initialization
            .map(makeValue)
            .assign(to: \.bufferedValue, onWeaklyHeld: self) // buffer latest update value

        // 2. Publish ContentBlockingAssets(Rules+Scripts) for WKUserContentController per subscription
        self.userContentBlockingAssets = $bufferedValue
            .compactMap { $0 } // drop initial nil
            .map { value in
                UserContentController.ContentBlockingAssets(contentRuleLists: value.rulesUpdate.rules
                                                                .reduce(into: [String: WKContentRuleList](), { result, rules in
                                                                    result[rules.name] = rules.rulesList
                                                                }),
                                                            userScripts: UserScripts(with: value.sourceProvider),
                                                            completionTokens: value.rulesUpdate.completionTokens)
            }
            .eraseToAnyPublisher()

    }

}

protocol ContentBlockerRulesManagerProtocol: AnyObject {
    var updatesPublisher: AnyPublisher<ContentBlockerRulesManager.UpdateEvent, Never> { get }
    var currentRules: [ContentBlockerRulesManager.Rules] { get }
}
extension ContentBlockerRulesManager: ContentBlockerRulesManagerProtocol {}

final class ContentBlockingRulesCache: ContentBlockerRulesCaching {

    @UserDefaultsWrapper(key: .contentBlockingRulesCache, defaultValue: [:])
    public var contentRulesCache: [String: Date]

    var contentRulesCacheInterval: TimeInterval {
        7 * 24 * 3600
    }

}
