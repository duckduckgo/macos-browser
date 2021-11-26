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

final class ContentBlocking {

    static let privacyConfigurationManager = PrivacyConfigurationManager(dataProvider: AppPrivacyConfigurationDataProvider(),
                                                                         localProtection: DomainsProtectionUserDefaultsStore())

    static let contentBlockingUpdating = ContentBlockingUpdating()

    static let trackerDataManager = TrackerDataManager()

    private static let contentBlockingSource = DefaultContentBlockerRulesSource(trackerDataManager: trackerDataManager,
                                                                                privacyConfigManager: privacyConfigurationManager)

    static let contentBlockingManager = ContentBlockerRulesManager(source: contentBlockingSource,
                                                                   updateListener: contentBlockingUpdating,
                                                                   logger: OSLog.contentBlocking)
}
