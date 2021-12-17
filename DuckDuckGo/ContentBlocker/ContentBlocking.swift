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

// swiftlint:disable line_length
final class ContentBlocking {

    static let privacyConfigurationManager = PrivacyConfigurationManager(fetchedETag: DefaultConfigurationStorage.shared.loadEtag(for: .privacyConfiguration),
                                                                         fetchedData: DefaultConfigurationStorage.shared.loadData(for: .privacyConfiguration),
                                                                         embeddedDataProvider: AppPrivacyConfigurationDataProvider(),
                                                                         localProtection: DomainsProtectionUserDefaultsStore(),
                                                                         errorReporting: debugEvents)

    static let contentBlockingUpdating = ContentBlockingUpdating()

    static let trackerDataManager = TrackerDataManager(etag: DefaultConfigurationStorage.shared.loadEtag(for: .trackerRadar),
                                                       data: DefaultConfigurationStorage.shared.loadData(for: .trackerRadar),
                                                       errorReporting: debugEvents)

    static let contentBlockingManager = ContentBlockerRulesManager(rulesSource: contentBlockerRulesSource,
                                                                   exceptionsSource: exceptionsSource,
                                                                   updateListener: contentBlockingUpdating,
                                                                   logger: OSLog.contentBlocking)
    
    private static let contentBlockerRulesSource = ContentBlockerRulesLists(trackerDataManger: trackerDataManager)
    private static let exceptionsSource = DefaultContentBlockerRulesExceptionsSource(privacyConfigManager: privacyConfigurationManager)

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
    typealias NewRulesInfo = (rules: [ContentBlockerRulesManager.Rules],
                              changes: ContentBlockerRulesIdentifier.Difference,
                              completionTokens: Set<ContentBlockerRulesManager.CompletionToken>)
    typealias NewRulesPublisher = AnyPublisher<NewRulesInfo?, Never>

    private let contentBlockingRulesSubject = CurrentValueSubject<NewRulesInfo?, Never>(nil)

    var contentBlockingRules: NewRulesPublisher {
        contentBlockingRulesSubject.eraseToAnyPublisher()
    }

    func rulesManager(_ manager: ContentBlockerRulesManager,
                      didUpdateRules rules: [ContentBlockerRulesManager.Rules],
                      changes: ContentBlockerRulesIdentifier.Difference,
                      completionTokens: [ContentBlockerRulesManager.CompletionToken]) {
        contentBlockingRulesSubject.send((rules: rules, changes: changes, completionTokens: Set(completionTokens)))
    }

}

private class DomainsProtectionUserDefaultsStore: DomainsProtectionStore {

    private struct Keys {
        static let unprotectedDomains = "com.duckduckgo.contentblocker.unprotectedDomains"
    }

    private var userDefaults: UserDefaults? {
        return UserDefaults()
    }

    public private(set) var unprotectedDomains: Set<String> {
        get {
            guard let data = userDefaults?.data(forKey: Keys.unprotectedDomains) else { return Set<String>() }
            guard let unprotectedDomains = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSSet.self, from: data) as? Set<String> else {
                return Set<String>()
            }
            return unprotectedDomains
        }
        set(newUnprotectedDomain) {
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: newUnprotectedDomain, requiringSecureCoding: false) else { return }
            userDefaults?.set(data, forKey: Keys.unprotectedDomains)
        }
    }

    public func isHostUnprotected(forDomain domain: String) -> Bool {
        return unprotectedDomains.contains(domain)
    }

    public func disableProtection(forDomain domain: String) {
        var domains = unprotectedDomains
        domains.insert(domain)
        unprotectedDomains = domains
    }

    public func enableProtection(forDomain domain: String) {
        var domains = unprotectedDomains
        domains.remove(domain)
        unprotectedDomains = domains
    }
}

// swiftlint:enable line_length
