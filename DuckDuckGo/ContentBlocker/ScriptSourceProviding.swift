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
import BrowserServicesKit

protocol ScriptSourceProviding {

    func reload(knownChanges: ContentBlockerRulesIdentifier.Difference?)
    var contentBlockerRulesConfig: ContentBlockerUserScriptConfig? { get }
    var surrogatesConfig: SurrogatesUserScriptConfig? { get }
    var gpcSource: String { get }
    var navigatorCredentialsSource: String { get }
    var clickToLoadSource: String { get }

    var sourceUpdatedPublisher: AnyPublisher<ContentBlockerRulesIdentifier.Difference?, Never> { get }

}

final class DefaultScriptSourceProvider: ScriptSourceProviding {

    static var shared: ScriptSourceProviding = DefaultScriptSourceProvider()

    private(set) var contentBlockerRulesConfig: ContentBlockerUserScriptConfig?
    private(set) var surrogatesConfig: SurrogatesUserScriptConfig?
    private(set) var gpcSource: String = ""
    private(set) var navigatorCredentialsSource: String = ""
    private(set) var clickToLoadSource: String = ""

    private let sourceUpdatedSubject = PassthroughSubject<ContentBlockerRulesIdentifier.Difference?, Never>()
    var sourceUpdatedPublisher: AnyPublisher<ContentBlockerRulesIdentifier.Difference?, Never> {
        sourceUpdatedSubject.eraseToAnyPublisher()
    }

    let configStorage: ConfigurationStoring
    let privacyConfigurationManager: PrivacyConfigurationManager
    let contentBlockingManager: ContentBlockerRulesManager

    var contentBlockingRulesUpdatedCancellable: AnyCancellable!

    private init(configStorage: ConfigurationStoring = DefaultConfigurationStorage.shared,
                 privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.privacyConfigurationManager,
                 contentBlockingManager: ContentBlockerRulesManager = ContentBlocking.contentBlockingManager,
                 contentBlockingUpdating: ContentBlockingUpdating = ContentBlocking.contentBlockingUpdating) {
        self.configStorage = configStorage
        self.privacyConfigurationManager = privacyConfigurationManager
        self.contentBlockingManager = contentBlockingManager

        attachListeners(contentBlockingUpdating: contentBlockingUpdating)

        reload(knownChanges: nil)
    }

    private func attachListeners(contentBlockingUpdating: ContentBlockingUpdating) {
        let cancellable = contentBlockingUpdating.contentBlockingRules.receive(on: RunLoop.main).sink(receiveValue: { [weak self] newRulesInfo in
            guard let self = self, let newRulesInfo = newRulesInfo else { return }

            self.reload(knownChanges: newRulesInfo.changes)
        })
        contentBlockingRulesUpdatedCancellable = cancellable
    }

    func reload(knownChanges: ContentBlockerRulesIdentifier.Difference?) {
        contentBlockerRulesConfig = buildContentBlockerRulesConfig()
        surrogatesConfig = buildSurrogatesConfig()
        gpcSource = buildGPCSource()
        navigatorCredentialsSource = buildNavigatorCredentialsSource()
        clickToLoadSource = buildClickToLoadSource()
        sourceUpdatedSubject.send( knownChanges )
    }

    private func buildContentBlockerRulesConfig() -> ContentBlockerUserScriptConfig {
        
        let tdsName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName
        let trackerData = contentBlockingManager.currentRules.first(where: { $0.name == tdsName})?.trackerData
        
        return DefaultContentBlockerUserScriptConfig(privacyConfiguration: privacyConfigurationManager.privacyConfig,
                                                     trackerData: trackerData)
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
                                                 isDebugBuild: isDebugBuild)
    }
    
    private func buildGPCSource() -> String {
        let privacyConfiguration = privacyConfigurationManager.privacyConfig
        let exceptions = privacyConfiguration.tempUnprotectedDomains +
                            privacyConfiguration.exceptionsList(forFeature: .gpc)
        let privSettings = PrivacySecurityPreferences()
        let localUnprotectedDomains = privacyConfiguration.userUnprotectedDomains.joined(separator: "\n")
        
        return GPCUserScript.loadJS("gpc", from: .main, withReplacements: [
            "$GPC_ENABLED$": privacyConfiguration.isEnabled(featureKey: .gpc) && privSettings.gpcEnabled ? "true" : "false",
            "$GPC_EXCEPTIONS$": exceptions.joined(separator: "\n"),
            "$USER_UNPROTECTED_DOMAINS$": localUnprotectedDomains
        ])
    }

    private func buildNavigatorCredentialsSource() -> String {
        let privacyConfiguration = privacyConfigurationManager.privacyConfig
        let unprotectedDomains = privacyConfiguration.tempUnprotectedDomains
        let contentBlockingExceptions = privacyConfiguration.exceptionsList(forFeature: .navigatorCredentials)
        if !privacyConfiguration.isEnabled(featureKey: .navigatorCredentials) {
            return ""
        }
        return NavigatorCredentialsUserScript.loadJS("navigatorCredentials", from: .main, withReplacements: [
             "$USER_UNPROTECTED_DOMAINS$": "",
             "$CREDENTIALS_EXCEPTIONS$": (unprotectedDomains + contentBlockingExceptions).joined(separator: "\n")
        ])
    }
    
    private func loadTextFile(_ fileName: String, _ fileExt: String) -> String {
        let sdkUrl = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExt
        )
        var data = ""
        do {
            data = try String(contentsOf: sdkUrl!)
        } catch let error as NSError {
            print(error.debugDescription)
        }
        
        return data
    }

    private func buildClickToLoadSource() -> String {
        // For now bundle FB SDK and associated config, as they diverged from the extension
        let fbSDK = loadTextFile("fb-sdk", "js")
        let config = loadTextFile("clickToLoadConfig", "json")
        return ContentBlockerRulesUserScript.loadJS("clickToLoad", from: .main, withReplacements: [
            "${fb-sdk.js}": fbSDK,
            "${clickToLoadConfig.json}": config
        ])
    }
}
