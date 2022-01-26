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

    static let privacyConfigurationManager
        = PrivacyConfigurationManager(fetchedETag: DefaultConfigurationStorage.shared.loadEtag(for: .privacyConfiguration),
                                      fetchedData: DefaultConfigurationStorage.shared.loadData(for: .privacyConfiguration),
                                      embeddedDataProvider: AppPrivacyConfigurationDataProvider(),
                                      localProtection: LocalUnprotectedDomains.shared,
                                      errorReporting: debugEvents)

    static let contentBlockingUpdating = ContentBlockingUpdating()

    static let trackerDataManager = TrackerDataManager(etag: DefaultConfigurationStorage.shared.loadEtag(for: .trackerRadar),
                                                       data: DefaultConfigurationStorage.shared.loadData(for: .trackerRadar),
                                                       errorReporting: debugEvents)

    static let contentBlockingManager = ContentBlockerRulesManager(rulesSource: contentBlockerRulesSource,
                                                                   exceptionsSource: exceptionsSource,
                                                                   cache: ContentBlockingRulesCache(),
                                                                   updateListener: contentBlockingUpdating,
                                                                   logger: OSLog.contentBlocking)
    
    private static let contentBlockerRulesSource = ContentBlockerRulesLists(trackerDataManger: trackerDataManager)
    private static let exceptionsSource = DefaultContentBlockerRulesExceptionsSource(privacyConfigManager: privacyConfigurationManager)

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

final class ContentBlockingUpdating: ContentBlockerRulesUpdating {
    typealias NewRulesInfo = (rules: [ContentBlockerRulesManager.Rules],
                              changes: [String: ContentBlockerRulesIdentifier.Difference],
                              completionTokens: Set<ContentBlockerRulesManager.CompletionToken>)
    typealias NewRulesPublisher = AnyPublisher<NewRulesInfo?, Never>

    private let contentBlockingRulesSubject = CurrentValueSubject<NewRulesInfo?, Never>(nil)

    var contentBlockingRules: NewRulesPublisher {
        contentBlockingRulesSubject.eraseToAnyPublisher()
    }

    func rulesManager(_ manager: ContentBlockerRulesManager,
                      didUpdateRules rules: [ContentBlockerRulesManager.Rules],
                      changes: [String: ContentBlockerRulesIdentifier.Difference],
                      completionTokens: [ContentBlockerRulesManager.CompletionToken]) {
        contentBlockingRulesSubject.send((rules: rules, changes: changes, completionTokens: Set(completionTokens)))
    }

}

final class ContentBlockingRulesCache: ContentBlockerRulesCaching {

    @UserDefaultsWrapper(key: .contentBlockingRulesCache, defaultValue: [:])
    public var contentRulesCache: [String: Date]

    var contentRulesCacheInterval: TimeInterval {
        7 * 24 * 3600
    }

}
