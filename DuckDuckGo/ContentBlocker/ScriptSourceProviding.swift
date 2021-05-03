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

    var sourceUpdatedPublisher: AnyPublisher<Void, Never> { get }

}

final class DefaultScriptSourceProvider: ScriptSourceProviding {

    static var shared: ScriptSourceProviding = DefaultScriptSourceProvider()

    @Published
    private(set) var contentBlockerRulesSource: String = ""
    @Published
    private(set) var contentBlockerSource: String = ""

    private let sourceUpdatedSubject = PassthroughSubject<Void, Never>()

    var sourceUpdatedPublisher: AnyPublisher<Void, Never> {
        sourceUpdatedSubject.eraseToAnyPublisher()
    }

    let configStorage: ConfigurationStoring

    private init(configStorage: ConfigurationStoring = DefaultConfigurationStorage.shared) {
        self.configStorage = configStorage
        reload()
    }

    func reload() {
        contentBlockerRulesSource = buildContentBlockerRulesSource()
        contentBlockerSource = buildContentBlockerSource()
        sourceUpdatedSubject.send( () )
    }

    private func buildContentBlockerRulesSource() -> String {
        let unprotectedDomains = configStorage.loadData(for: .temporaryUnprotectedSites)?.utf8String() ?? ""
        return ContentBlockerRulesUserScript.loadJS("contentblockerrules", from: .main, withReplacements: [
            "${unprotectedDomains}": unprotectedDomains
        ])
    }

    private func buildContentBlockerSource() -> String {

        // Use sensible defaults in case the upstream data is unparsable
        #warning("encodedTrackerData Data Race here!")
        let trackerData = TrackerRadarManager.shared.encodedTrackerData
        let surrogates = configStorage.loadData(for: .surrogates)?.utf8String() ?? ""
        let unprotectedSites = configStorage.loadData(for: .temporaryUnprotectedSites)?.utf8String() ?? ""

        return ContentBlockerUserScript.loadJS("contentblocker", from: .main, withReplacements: [
            "${unprotectedDomains}": unprotectedSites,
            "${trackerData}": trackerData,
            "${surrogates}": surrogates
        ])
    }

}
