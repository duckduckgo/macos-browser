//
//  ScriptSourceProviding.swift
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
import Combine
import Common
import BrowserServicesKit
import Configuration
import TrackerRadarKit

protocol ScriptSourceProviding {

    var contentBlockerRulesConfig: ContentBlockerUserScriptConfig? { get }
    var surrogatesConfig: SurrogatesUserScriptConfig? { get }
    var privacyConfigurationManager: PrivacyConfigurationManaging { get }
    var autofillSourceProvider: AutofillUserScriptSourceProvider? { get }
    var sessionKey: String? { get }
    var messageSecret: String? { get }
    var onboardingActionsManager: OnboardingActionsManaging? { get }
    func buildAutofillSource() -> AutofillUserScriptSourceProvider

}

// refactor: ScriptSourceProvider to be passed to init methods as `some ScriptSourceProviding`, DefaultScriptSourceProvider to be killed
// swiftlint:disable:next identifier_name
@MainActor func DefaultScriptSourceProvider() -> ScriptSourceProviding {
    ScriptSourceProvider(configStorage: Application.appDelegate.configurationStore, privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager, webTrackingProtectionPreferences: WebTrackingProtectionPreferences.shared, contentBlockingManager: ContentBlocking.shared.contentBlockingManager, trackerDataManager: ContentBlocking.shared.trackerDataManager, tld: ContentBlocking.shared.tld)
}

struct ScriptSourceProvider: ScriptSourceProviding {
    private(set) var contentBlockerRulesConfig: ContentBlockerUserScriptConfig?
    private(set) var surrogatesConfig: SurrogatesUserScriptConfig?
    private(set) var onboardingActionsManager: OnboardingActionsManaging?
    private(set) var autofillSourceProvider: AutofillUserScriptSourceProvider?
    private(set) var sessionKey: String?
    private(set) var messageSecret: String?

    let configStorage: ConfigurationStoring
    let privacyConfigurationManager: PrivacyConfigurationManaging
    let contentBlockingManager: ContentBlockerRulesManagerProtocol
    let trackerDataManager: TrackerDataManager
    let webTrakcingProtectionPreferences: WebTrackingProtectionPreferences
    let tld: TLD

    @MainActor
    init(configStorage: ConfigurationStoring,
         privacyConfigurationManager: PrivacyConfigurationManaging,
         webTrackingProtectionPreferences: WebTrackingProtectionPreferences,
         contentBlockingManager: ContentBlockerRulesManagerProtocol,
         trackerDataManager: TrackerDataManager,
         tld: TLD) {

        self.configStorage = configStorage
        self.privacyConfigurationManager = privacyConfigurationManager
        self.webTrakcingProtectionPreferences = webTrackingProtectionPreferences
        self.contentBlockingManager = contentBlockingManager
        self.trackerDataManager = trackerDataManager
        self.tld = tld

        self.contentBlockerRulesConfig = buildContentBlockerRulesConfig()
        self.surrogatesConfig = buildSurrogatesConfig()
        self.sessionKey = generateSessionKey()
        self.messageSecret = generateSessionKey()
        self.autofillSourceProvider = buildAutofillSource()
        self.onboardingActionsManager = buildOnboardingActionsManager()
    }

    private func generateSessionKey() -> String {
        return UUID().uuidString
    }

    public func buildAutofillSource() -> AutofillUserScriptSourceProvider {
        let privacyConfig = self.privacyConfigurationManager.privacyConfig
        return DefaultAutofillSourceProvider.Builder(privacyConfigurationManager: privacyConfigurationManager,
                                                     properties: ContentScopeProperties(gpcEnabled: webTrakcingProtectionPreferences.isGPCEnabled,
                                                                                        sessionKey: self.sessionKey ?? "",
                                                                                        messageSecret: self.messageSecret ?? "",
                                                                                        featureToggles: ContentScopeFeatureToggles.supportedFeaturesOnMacOS(privacyConfig)),
                                                     isDebug: AutofillPreferences().debugScriptEnabled)
                .withJSLoading()
                .build()
    }

    private func buildContentBlockerRulesConfig() -> ContentBlockerUserScriptConfig {

        let tdsName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
        let trackerData = contentBlockingManager.currentRules.first(where: { $0.name == tdsName})?.trackerData

        let ctlTrackerData = (contentBlockingManager.currentRules.first(where: {
            $0.name == DefaultContentBlockerRulesListsSource.Constants.clickToLoadRulesListName
        })?.trackerData)

        return DefaultContentBlockerUserScriptConfig(privacyConfiguration: privacyConfigurationManager.privacyConfig,
                                                     trackerData: trackerData,
                                                     ctlTrackerData: ctlTrackerData,
                                                     tld: tld,
                                                     trackerDataManager: trackerDataManager)
    }

    private func buildSurrogatesConfig() -> SurrogatesUserScriptConfig {

        let isDebugBuild: Bool
#if DEBUG
        isDebugBuild = true
#else
        isDebugBuild = false
#endif

        let surrogates = configStorage.loadData(for: .surrogates)?.utf8String() ?? ""
        let allTrackers = mergeTrackerDataSets(rules: contentBlockingManager.currentRules)
        return DefaultSurrogatesUserScriptConfig(privacyConfig: privacyConfigurationManager.privacyConfig,
                                                 surrogates: surrogates,
                                                 trackerData: allTrackers.trackerData,
                                                 encodedSurrogateTrackerData: allTrackers.encodedTrackerData,
                                                 trackerDataManager: trackerDataManager,
                                                 tld: tld,
                                                 isDebugBuild: isDebugBuild)
    }

    @MainActor
    private func buildOnboardingActionsManager() -> OnboardingActionsManaging {
        return OnboardingActionsManager(
            navigationDelegate: WindowControllersManager.shared,
            dockCustomization: DockCustomizer(),
            defaultBrowserProvider: SystemDefaultBrowserProvider(),
            appearancePreferences: AppearancePreferences.shared,
            startupPreferences: StartupPreferences.shared)
    }

    private func loadTextFile(_ fileName: String, _ fileExt: String) -> String? {
        let url = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExt
        )
        guard let data = try? String(contentsOf: url!) else {
            assertionFailure("Failed to load text file")
            return nil
        }

        return data
    }

    private func mergeTrackerDataSets(rules: [ContentBlockerRulesManager.Rules]) -> (trackerData: TrackerData, encodedTrackerData: String) {
        var combinedTrackers: [String: KnownTracker] = [:]
        var combinedEntities: [String: Entity] = [:]
        var combinedDomains: [String: String] = [:]
        var cnames: [TrackerData.CnameDomain: TrackerData.TrackerDomain]? = [:]

        let setsToCombine = [ DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName, DefaultContentBlockerRulesListsSource.Constants.clickToLoadRulesListName ]

        for setName in setsToCombine {
            if let ruleSetIndex = contentBlockingManager.currentRules.firstIndex(where: { $0.name == setName }) {
                let ruleSet = rules[ruleSetIndex]

                combinedTrackers = combinedTrackers.merging(ruleSet.trackerData.trackers) { (_, new) in new }
                combinedEntities = combinedEntities.merging(ruleSet.trackerData.entities) { (_, new) in new }
                combinedDomains = combinedDomains.merging(ruleSet.trackerData.domains) { (_, new) in new }
                if setName == DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName {
                    cnames = ruleSet.trackerData.cnames
                }
            }
        }

        let combinedTrackerData = TrackerData(trackers: combinedTrackers,
                            entities: combinedEntities,
                            domains: combinedDomains,
                            cnames: cnames)

        let surrogateTDS = ContentBlockerRulesManager.extractSurrogates(from: combinedTrackerData)
        let encodedTrackerData = encodeTrackerData(surrogateTDS)

        return (trackerData: combinedTrackerData, encodedTrackerData: encodedTrackerData)
    }

    private func encodeTrackerData(_ trackerData: TrackerData) -> String {
        let encodedData = try? JSONEncoder().encode(trackerData)
        return String(data: encodedData!, encoding: .utf8)!
    }
}
