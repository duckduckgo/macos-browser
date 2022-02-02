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
import BrowserServicesKit
import Combine
import os.log

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
                                                errorReporting: Self.debugEvents)

        contentBlockerRulesSource = ContentBlockerRulesLists(trackerDataManger: trackerDataManager)
        exceptionsSource = DefaultContentBlockerRulesExceptionsSource(privacyConfigManager: privacyConfigurationManager)

        contentBlockingManager = ContentBlockerRulesManager(rulesSource: contentBlockerRulesSource,
                                                            exceptionsSource: exceptionsSource,
                                                            cache: ContentBlockingRulesCache(),
                                                            logger: OSLog.contentBlocking)
        contentBlockingUpdating = ContentBlockingUpdating(contentBlockerRulesManager: contentBlockingManager)

    }

    private static let debugEvents = EventMapping<ContentBlockerDebugEvents> { event, scope, error, parameters, onComplete in
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
        }

        Pixel.fire(.debug(event: domainEvent, error: error), withAdditionalParameters: parameters, onComplete: onComplete)
    }
}

final class ContentBlockingUpdating {

    private struct RulesAndScripts {
        let rulesUpdate: ContentBlockerRulesManager.UpdateEvent
        let userScripts: UserScripts

        init(rulesUpdate: ContentBlockerRulesManager.UpdateEvent) {
            self.rulesUpdate = rulesUpdate
            self.userScripts = UserScripts(with: DefaultScriptSourceProvider())
        }
    }
    @Published private var rulesAndScripts: RulesAndScripts?
    private var cancellable: AnyCancellable?

    private(set) var userContentBlockingAssets: AnyPublisher<UserContentController.ContentBlockingAssets, Never>!
    private(set) var completionTokensPublisher: AnyPublisher<[ContentBlockerRulesManager.CompletionToken], Never>!

    init(contentBlockerRulesManager: ContentBlockerRulesManagerProtocol,
         privacySecurityPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared) {

        // 1. Collect updates from ContentBlockerRulesManager and generate UserScripts based on its output
        cancellable = contentBlockerRulesManager.updatesPublisher
            // regenerate UserScripts on gpcEnabled preference updated
            .combineLatest(privacySecurityPreferences.$gpcEnabled)
            .map { $0.0 } // drop gpcEnabled value: $0.1
            .map(RulesAndScripts.init(rulesUpdate:)) // regenerate UserScripts
            .weakAssign(to: \.rulesAndScripts, on: self) // buffer latest update value

        // 2. Publish ContentBlockingAssets(Rules+Scripts) for WKUserContentController per subscription
        self.userContentBlockingAssets = $rulesAndScripts
            .compactMap { $0 } // drop initial nil
            .map { rulesAndScripts in
                UserContentController.ContentBlockingAssets(rules: rulesAndScripts.rulesUpdate.rules
                                                                .reduce(into: [String: WKContentRuleList](), { result, rules in
                                                                    result[rules.name] = rules.rulesList
                                                                }),
                                                            scripts: rulesAndScripts.userScripts)
            }
            .eraseToAnyPublisher()

        // 3. Publish completion tokens for the Content Blocking Assets Regeneration operation for waiting Privacy Dashboard
        self.completionTokensPublisher = $rulesAndScripts
            .compactMap { $0 } // drop initial nil
            .map(\.rulesUpdate.completionTokens)
            .eraseToAnyPublisher()

    }

}

protocol ContentBlockerRulesManagerProtocol: AnyObject {
    var updatesPublisher: AnyPublisher<ContentBlockerRulesManager.UpdateEvent, Never> { get }
}
extension ContentBlockerRulesManager: ContentBlockerRulesManagerProtocol {}

final class ContentBlockingRulesCache: ContentBlockerRulesCaching {

    @UserDefaultsWrapper(key: .contentBlockingRulesCache, defaultValue: [:])
    public var contentRulesCache: [String: Date]

    var contentRulesCacheInterval: TimeInterval {
        7 * 24 * 3600
    }

}
