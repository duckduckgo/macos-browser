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

protocol ScriptSourceProviding {

    func reload()
    var contentBlockerRulesSource: String { get }
    var contentBlockerSource: String { get }
    var gpcSource: String { get }
    var navigatorCredentialsSource: String { get }

    var sourceUpdatedPublisher: AnyPublisher<Void, Never> { get }

}

final class DefaultScriptSourceProvider: ScriptSourceProviding {

    static var shared: ScriptSourceProviding = DefaultScriptSourceProvider()

    @Published
    private(set) var contentBlockerRulesSource: String = ""
    @Published
    private(set) var contentBlockerSource: String = ""
    @Published
    private(set) var gpcSource: String = ""
    private(set) var navigatorCredentialsSource: String = ""

    private let sourceUpdatedSubject = PassthroughSubject<Void, Never>()

    var sourceUpdatedPublisher: AnyPublisher<Void, Never> {
        sourceUpdatedSubject.eraseToAnyPublisher()
    }

    let configStorage: ConfigurationStoring
    let privacyConfiguration: PrivacyConfigurationManagment

    private init(configStorage: ConfigurationStoring = DefaultConfigurationStorage.shared,
                 privacyConfiguration: PrivacyConfigurationManagment = PrivacyConfigurationManager.shared) {
        self.configStorage = configStorage
        self.privacyConfiguration = privacyConfiguration
        reload()
    }

    func reload() {
        contentBlockerRulesSource = buildContentBlockerRulesSource()
        contentBlockerSource = buildContentBlockerSource()
        gpcSource = buildGPCSource()
        navigatorCredentialsSource = buildNavigatorCredentialsSource()
        sourceUpdatedSubject.send( () )
    }

    private func buildContentBlockerRulesSource() -> String {
        let unprotectedDomains = privacyConfiguration.tempUnprotectedDomains
        let contentBlockingExceptions = privacyConfiguration.exceptionsList(forFeature: .contentBlocking)
        let protectionStore = DomainsProtectionUserDefaultsStore()
        return ContentBlockerRulesUserScript.loadJS("contentblockerrules", from: .main, withReplacements: [
            "TEMP_UNPROTECTED_DOMAINS": (unprotectedDomains + contentBlockingExceptions).joined(separator: "\n"),
            "USER_UNPROTECTED_DOMAINS": protectionStore.unprotectedDomains.joined(separator: "\n")
        ])
    }

    private func buildContentBlockerSource() -> String {

        // Use sensible defaults in case the upstream data is unparsable
        let trackerData = TrackerRadarManager.shared.encodedTrackerData
        let surrogates = configStorage.loadData(for: .surrogates)?.utf8String() ?? ""

        let remoteUnprotectedDomains = (privacyConfiguration.tempUnprotectedDomains.joined(separator: "\n"))
            + "\n"
            + (privacyConfiguration.exceptionsList(forFeature: .contentBlocking).joined(separator: "\n"))

        let protectionStore = DomainsProtectionUserDefaultsStore()
        let localUnprotectedDomains = protectionStore.unprotectedDomains.joined(separator: "\n")

        return ContentBlockerUserScript.loadJS("contentblocker", from: .main, withReplacements: [
            "IS_DEBUG": isDebugBuild ? "true" : "false",
            "TEMP_UNPROTECTED_DOMAINS": remoteUnprotectedDomains,
            "USER_UNPROTECTED_DOMAINS": localUnprotectedDomains,
            "TRACKER_DATA": trackerData,
            "SURROGATES": surrogates,
            "BLOCKING_ENABLED": privacyConfiguration.isEnabled(featureKey: .contentBlocking) ? "true" : "false"
        ])
    }
    
    private func buildGPCSource() -> String {
        let exceptions = privacyConfiguration.tempUnprotectedDomains +
                            privacyConfiguration.exceptionsList(forFeature: .gpc)
        let privSettings = PrivacySecurityPreferences()
        let protectionStore = DomainsProtectionUserDefaultsStore()
        let localUnprotectedDomains = protectionStore.unprotectedDomains.joined(separator: "\n")
        
        return GPCUserScript.loadJS("gpc", from: .main, withReplacements: [
            "GPC_ENABLED": privacyConfiguration.isEnabled(featureKey: .gpc) && privSettings.gpcEnabled ? "true" : "false",
            "GPC_EXCEPTIONS": exceptions.joined(separator: "\n"),
            "USER_UNPROTECTED_DOMAINS": localUnprotectedDomains
        ])
    }

    private func buildNavigatorCredentialsSource() -> String {
        let unprotectedDomains = privacyConfiguration.tempUnprotectedDomains
        let contentBlockingExceptions = privacyConfiguration.exceptionsList(forFeature: .navigatorCredentials)
        if !privacyConfiguration.isEnabled(featureKey: .navigatorCredentials) {
            return ""
        }
        return NavigatorCredentialsUserScript.loadJS("navigatorCredentials", from: .main, withReplacements: [
             "USER_UNPROTECTED_DOMAINS": "",
             "CREDENTIALS_EXCEPTIONS": (unprotectedDomains + contentBlockingExceptions).joined(separator: "\n")
        ])
    }

}
