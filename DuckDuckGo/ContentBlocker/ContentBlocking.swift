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

    static let privacyConfigurationManager = PrivacyConfigurationManager(fetchedETag: DefaultConfigurationStorage.shared.loadEtag(for: .privacyConfiguration),
                                                                         fetchedData: DefaultConfigurationStorage.shared.loadData(for: .privacyConfiguration),
                                                                         embeddedDataProvider: AppPrivacyConfigurationDataProvider(),
                                                                         localProtection: LocalUnprotectedDomains.shared,
                                                                         errorReporting: debugEvents)

    static let contentBlockingUpdating = ContentBlockingUpdating()

    static let trackerDataManager = TrackerDataManager(etag: DefaultConfigurationStorage.shared.loadEtag(for: .trackerRadar),
                                                       data: DefaultConfigurationStorage.shared.loadData(for: .trackerRadar),
                                                       errorReporting: debugEvents)

    static let contentBlockingManager = ContentBlockerRulesManager(source: contentBlockingSource,
                                                                   updateListener: contentBlockingUpdating,
                                                                   logger: OSLog.contentBlocking)

    private static let contentBlockingSource = DefaultContentBlockerRulesSource(trackerDataManager: trackerDataManager,
                                                                                privacyConfigManager: privacyConfigurationManager)

    private static let debugEvents = EventMapping<ContentBlockerDebugEvents> { event, error, parameters, onComplete in
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
            domainEvent = .contentBlockingTDSCompilationFailed

        case .contentBlockingTempListCompilationFailed:
            domainEvent = .contentBlockingTempListCompilationFailed

        case .contentBlockingAllowListCompilationFailed:
            domainEvent = .contentBlockingAllowListCompilationFailed

        case .contentBlockingUnpSitesCompilationFailed:
            domainEvent = .contentBlockingUnpSitesCompilationFailed

        case .contentBlockingFallbackCompilationFailed:
            domainEvent = .contentBlockingFallbackCompilationFailed
        }

        Pixel.fire(.debug(event: domainEvent, error: error), withAdditionalParameters: parameters, onComplete: onComplete)
    }
}

final class ContentBlockingUpdating: ContentBlockerRulesUpdating {
    typealias NewRulesInfo = (rules: ContentBlockerRulesManager.CurrentRules,
                              changes: ContentBlockerRulesIdentifier.Difference,
                              completionTokens: Set<ContentBlockerRulesManager.CompletionToken>)
    typealias NewRulesPublisher = AnyPublisher<NewRulesInfo?, Never>

    private let contentBlockingRulesSubject = CurrentValueSubject<NewRulesInfo?, Never>(nil)

    var contentBlockingRules: NewRulesPublisher {
        contentBlockingRulesSubject.eraseToAnyPublisher()
    }

    func rulesManager(_ manager: ContentBlockerRulesManager,
                      didUpdateRules rules: ContentBlockerRulesManager.CurrentRules,
                      changes: ContentBlockerRulesIdentifier.Difference,
                      completionTokens: [ContentBlockerRulesManager.CompletionToken]) {
        contentBlockingRulesSubject.send((rules: rules, changes: changes, completionTokens: Set(completionTokens)))
    }

}
