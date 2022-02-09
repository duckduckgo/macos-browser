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

    func reload(knownChanges: [String: ContentBlockerRulesIdentifier.Difference])
    var contentBlockerRulesConfig: ContentBlockerUserScriptConfig? { get }
    var surrogatesConfig: SurrogatesUserScriptConfig? { get }
    var privacyConfigurationManager: PrivacyConfigurationManager { get }
    var sessionKey: String? { get }
    var clickToLoadSource: String { get }

    var sourceUpdatedPublisher: AnyPublisher<[String: ContentBlockerRulesIdentifier.Difference], Never> { get }

}

final class DefaultScriptSourceProvider: ScriptSourceProviding {

    static var shared: ScriptSourceProviding = DefaultScriptSourceProvider()

    private(set) var contentBlockerRulesConfig: ContentBlockerUserScriptConfig?
    private(set) var surrogatesConfig: SurrogatesUserScriptConfig?
    private(set) var sessionKey: String?
    private(set) var clickToLoadSource: String = ""

    private let sourceUpdatedSubject = PassthroughSubject<[String: ContentBlockerRulesIdentifier.Difference], Never>()
    var sourceUpdatedPublisher: AnyPublisher<[String: ContentBlockerRulesIdentifier.Difference], Never> {
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

        reload(knownChanges: [:])
    }

    private func attachListeners(contentBlockingUpdating: ContentBlockingUpdating) {
        let cancellable = contentBlockingUpdating.contentBlockingRules.receive(on: RunLoop.main).sink(receiveValue: { [weak self] newRulesInfo in
            guard let self = self, let newRulesInfo = newRulesInfo else { return }

            self.reload(knownChanges: newRulesInfo.changes)
        })
        contentBlockingRulesUpdatedCancellable = cancellable
    }

    func reload(knownChanges: [String: ContentBlockerRulesIdentifier.Difference]) {
        contentBlockerRulesConfig = buildContentBlockerRulesConfig()
        surrogatesConfig = buildSurrogatesConfig()
        sessionKey = generateSessionKey()
        clickToLoadSource = buildClickToLoadSource()
        sourceUpdatedSubject.send( knownChanges )
    }

    private func generateSessionKey() -> String {
        return UUID().uuidString
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
                                                     trackerDataManager: ContentBlocking.trackerDataManager)
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
                                                 trackerDataManager: ContentBlocking.trackerDataManager,
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
