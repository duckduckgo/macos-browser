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

protocol ScriptSourceProviding {

    var contentBlockerRulesConfig: ContentBlockerUserScriptConfig? { get }
    var surrogatesConfig: SurrogatesUserScriptConfig? { get }
    var privacyConfigurationManager: PrivacyConfigurationManaging { get }
    var autofillSourceProvider: AutofillUserScriptSourceProvider? { get }
    var sessionKey: String? { get }
    var clickToLoadSource: String { get }
    func buildAutofillSource() -> AutofillUserScriptSourceProvider

}

// refactor: ScriptSourceProvider to be passed to init methods as `some ScriptSourceProviding`, DefaultScriptSourceProvider to be killed
// swiftlint:disable:next identifier_name
func DefaultScriptSourceProvider() -> ScriptSourceProviding {
    ScriptSourceProvider(configStorage: DefaultConfigurationStorage.shared, privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager, privacySettings: PrivacySecurityPreferences.shared, contentBlockingManager: ContentBlocking.shared.contentBlockingManager, trackerDataManager: ContentBlocking.shared.trackerDataManager, tld: ContentBlocking.shared.tld)
}

struct ScriptSourceProvider: ScriptSourceProviding {

    private(set) var contentBlockerRulesConfig: ContentBlockerUserScriptConfig?
    private(set) var surrogatesConfig: SurrogatesUserScriptConfig?
    private(set) var autofillSourceProvider: AutofillUserScriptSourceProvider?
    private(set) var sessionKey: String?
    private(set) var clickToLoadSource: String = ""

    let configStorage: ConfigurationStoring
    let privacyConfigurationManager: PrivacyConfigurationManaging
    let contentBlockingManager: ContentBlockerRulesManagerProtocol
    let trackerDataManager: TrackerDataManager
    let privacySettings: PrivacySecurityPreferences
    let tld: TLD

    init(configStorage: ConfigurationStoring,
         privacyConfigurationManager: PrivacyConfigurationManaging,
         privacySettings: PrivacySecurityPreferences,
         contentBlockingManager: ContentBlockerRulesManagerProtocol,
         trackerDataManager: TrackerDataManager,
         tld: TLD) {

        self.configStorage = configStorage
        self.privacyConfigurationManager = privacyConfigurationManager
        self.privacySettings = privacySettings
        self.contentBlockingManager = contentBlockingManager
        self.trackerDataManager = trackerDataManager
        self.tld = tld

        self.contentBlockerRulesConfig = buildContentBlockerRulesConfig()
        self.surrogatesConfig = buildSurrogatesConfig()
        self.sessionKey = generateSessionKey()
        self.clickToLoadSource = buildClickToLoadSource()
        self.autofillSourceProvider = buildAutofillSource()
    }

    private func generateSessionKey() -> String {
        return UUID().uuidString
    }

    public func buildAutofillSource() -> AutofillUserScriptSourceProvider {

        return DefaultAutofillSourceProvider(privacyConfigurationManager: self.privacyConfigurationManager,
                                             properties: ContentScopeProperties(gpcEnabled: privacySettings.gpcEnabled,
                                                                                sessionKey: self.sessionKey ?? "",
                                                                                featureToggles: ContentScopeFeatureToggles.supportedFeaturesOnMacOS))
    }

    private func buildContentBlockerRulesConfig() -> ContentBlockerUserScriptConfig {

        let tdsName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
        let trackerData = contentBlockingManager.currentRules.first(where: { $0.name == tdsName})?.trackerData

        let ctlTrackerData = (contentBlockingManager.currentRules.first(where: {
            $0.name == ContentBlockerRulesLists.Constants.clickToLoadRulesListName
        })?.trackerData) ?? ContentBlockerRulesLists.fbTrackerDataSet

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
        let tdsName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
        let rules = contentBlockingManager.currentRules.first(where: { $0.name == tdsName})
        return DefaultSurrogatesUserScriptConfig(privacyConfig: privacyConfigurationManager.privacyConfig,
                                                 surrogates: surrogates,
                                                 trackerData: rules?.trackerData,
                                                 encodedSurrogateTrackerData: rules?.encodedTrackerData,
                                                 trackerDataManager: trackerDataManager,
                                                 tld: tld,
                                                 isDebugBuild: isDebugBuild)
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

    private func loadFont(_ fileName: String, _ fileExt: String) -> String? {
        let url = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExt
        )
        guard let base64String = try? Data(contentsOf: url!).base64EncodedString() else {
            assertionFailure("Failed to load font")
            return nil
        }

        let font = "data:application/octet-stream;base64," + base64String
        return font
    }

    private func buildClickToLoadSource() -> String {
        // For now bundle FB SDK and associated config, as they diverged from the extension
        let fbSDK = loadTextFile("fb-sdk", "js")
        let config = loadTextFile("clickToLoadConfig", "json")
        let proximaRegFont = loadFont("ProximaNova-Reg-webfont", "woff2")
        let proximaBoldFont = loadFont("ProximaNova-Bold-webfont", "woff2")
        return ContentBlockerRulesUserScript.loadJS("clickToLoad", from: .main, withReplacements: [
            "${fb-sdk.js}": fbSDK!,
            "${clickToLoadConfig.json}": config!,
            "${proximaRegFont}": proximaRegFont!,
            "${proximaBoldFont}": proximaBoldFont!
        ])
    }

}
