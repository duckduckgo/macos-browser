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
import Common

protocol ContentBlockingProtocol {

    var privacyConfigurationManager: PrivacyConfigurationManaging { get }
    var contentBlockingManager: ContentBlockerRulesManagerProtocol { get }
    var trackerDataManager: TrackerDataManager { get }
    var tld: TLD { get }

    var contentBlockingAssetsPublisher: AnyPublisher<UserContentUpdating.NewContent, Never> { get }

}

typealias AnyContentBlocking = any ContentBlockingProtocol & AdClickAttributionDependencies

// refactor: ContentBlocking.shared to be removed, ContentBlockingProtocol to be renamed to ContentBlocking
// ContentBlocking to be passed to init methods as `some ContentBlocking`
typealias ContentBlocking = AppContentBlocking
extension ContentBlocking {
    static var shared: AnyContentBlocking { PrivacyFeatures.contentBlocking }
}

final class AppContentBlocking {
    let privacyConfigurationManager: PrivacyConfigurationManaging
    let trackerDataManager: TrackerDataManager
    let contentBlockingManager: ContentBlockerRulesManagerProtocol
    let userContentUpdating: UserContentUpdating

    let tld = TLD()

    let adClickAttribution: AdClickAttributing
    let adClickAttributionRulesProvider: AdClickAttributionRulesProviding

    private let contentBlockerRulesSource: ContentBlockerRulesLists
    private let exceptionsSource: DefaultContentBlockerRulesExceptionsSource

    // keeping whole ContentBlocking state initialization in one place to avoid races between updates publishing and rules storing
    init() {
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
        
        adClickAttribution = AdClickAttributionFeature(with: privacyConfigurationManager)

        contentBlockerRulesSource = ContentBlockerRulesLists(trackerDataManager: trackerDataManager, adClickAttribution: adClickAttribution)
        exceptionsSource = DefaultContentBlockerRulesExceptionsSource(privacyConfigManager: privacyConfigurationManager)

        contentBlockingManager = ContentBlockerRulesManager(rulesSource: contentBlockerRulesSource,
                                                            exceptionsSource: exceptionsSource,
                                                            cache: ContentBlockingRulesCache(),
                                                            errorReporting: Self.debugEvents,
                                                            logger: OSLog.contentBlocking)
        userContentUpdating = UserContentUpdating(contentBlockerRulesManager: contentBlockingManager,
                                                  privacyConfigurationManager: privacyConfigurationManager,
                                                  trackerDataManager: trackerDataManager,
                                                  configStorage: configStorage,
                                                  privacySecurityPreferences: PrivacySecurityPreferences.shared,
                                                  tld: tld)
        
        adClickAttributionRulesProvider = AdClickAttributionRulesProvider(config: adClickAttribution,
                                                                          compiledRulesSource: contentBlockingManager,
                                                                          exceptionsSource: exceptionsSource,
                                                                          errorReporting: attributionDebugEvents,
                                                                          compilationErrorReporting: Self.debugEvents)
    }

    private static let debugEvents = EventMapping<ContentBlockerDebugEvents> { event, error, parameters, onComplete in
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
            
        case .contentBlockingCompilationFailed(let listName, let component):
            let defaultTDSListName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
            
            let listType: Pixel.Event.CompileRulesListType
            switch listName {
            case defaultTDSListName:
                listType = .tds
            case ContentBlockerRulesLists.Constants.clickToLoadRulesListName:
                listType = .clickToLoad
            case AdClickAttributionRulesSplitter.blockingAttributionRuleListName(forListNamed: defaultTDSListName):
                listType = .blockingAttribution
            case AdClickAttributionRulesProvider.Constants.attributedTempRuleListName:
                listType = .attributed
            default:
                listType = .unknown
            }

            domainEvent = .contentBlockingCompilationFailed(listType: listType, component: component)

        case .contentBlockingCompilationTime:
            // Temporarily avoid firing this pixel. This can be re-enabled if it's determined to be necessary later.
            // domainEvent = .contentBlockingCompilationTime
            return
        }

        Pixel.fire(.debug(event: domainEvent, error: error), withAdditionalParameters: parameters, onComplete: onComplete)
    }
    
    // MARK: - Ad Click Attribution

    let attributionEvents = EventMapping<AdClickAttributionEvents> { event, _, parameters, _ in
        let domainEvent: Pixel.Event
        switch event {
        case .adAttributionDetected:
            domainEvent = .adClickAttributionDetected
        case .adAttributionActive:
            domainEvent = .adClickAttributionActive
        }

        Pixel.fire(domainEvent, withAdditionalParameters: parameters ?? [:])
    }
    
    let attributionDebugEvents = EventMapping<AdClickAttributionDebugEvents> { event, _, _, _ in
        let domainEvent: Pixel.Event.Debug
        switch event {
        case .adAttributionCompilationFailedForAttributedRulesList:
            domainEvent = .adAttributionCompilationFailedForAttributedRulesList
        case .adAttributionGlobalAttributedRulesDoNotExist:
            domainEvent = .adAttributionGlobalAttributedRulesDoNotExist
        case .adAttributionDetectionHeuristicsDidNotMatchDomain:
            domainEvent = .adAttributionDetectionHeuristicsDidNotMatchDomain
        case .adAttributionLogicUnexpectedStateOnRulesCompiled:
            domainEvent = .adAttributionLogicUnexpectedStateOnRulesCompiled
        case .adAttributionLogicUnexpectedStateOnInheritedAttribution:
            domainEvent = .adAttributionLogicUnexpectedStateOnInheritedAttribution
        case .adAttributionLogicUnexpectedStateOnRulesCompilationFailed:
            domainEvent = .adAttributionLogicUnexpectedStateOnRulesCompilationFailed
        case .adAttributionDetectionInvalidDomainInParameter:
            domainEvent = .adAttributionDetectionInvalidDomainInParameter
        case .adAttributionLogicRequestingAttributionTimedOut:
            domainEvent = .adAttributionLogicRequestingAttributionTimedOut
        case .adAttributionLogicWrongVendorOnSuccessfulCompilation:
            domainEvent = .adAttributionLogicWrongVendorOnSuccessfulCompilation
        case .adAttributionLogicWrongVendorOnFailedCompilation:
            domainEvent = .adAttributionLogicWrongVendorOnFailedCompilation
        }

        Pixel.fire(.debug(event: domainEvent, error: nil),
                   includeAppVersionParameter: false)
    }
}

protocol ContentBlockerRulesManagerProtocol: CompiledRuleListsSource {
    var updatesPublisher: AnyPublisher<ContentBlockerRulesManager.UpdateEvent, Never> { get }
    var currentRules: [ContentBlockerRulesManager.Rules] { get }
    func scheduleCompilation() -> ContentBlockerRulesManager.CompletionToken
}

extension ContentBlockerRulesManager: ContentBlockerRulesManagerProtocol {}

final class ContentBlockingRulesCache: ContentBlockerRulesCaching {

    @UserDefaultsWrapper(key: .contentBlockingRulesCache, defaultValue: [:])
    public var contentRulesCache: [String: Date]

    var contentRulesCacheInterval: TimeInterval {
        7 * 24 * 3600
    }

}

extension AppContentBlocking: ContentBlockingProtocol {

    var contentBlockingAssetsPublisher: AnyPublisher<UserContentUpdating.NewContent, Never> {
        self.userContentUpdating.userContentBlockingAssets
    }

}
