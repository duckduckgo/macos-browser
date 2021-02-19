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

protocol ScriptSourceProviding {

    func reload()
    var contentBlockerRulesSource: String { get }
    var contentBlockerSource: String { get }

}

class DefaultScriptSourceProvider: ScriptSourceProviding {

    static var shared: ScriptSourceProviding = DefaultScriptSourceProvider()

    private(set) var contentBlockerRulesSource: String = ""
    private(set) var contentBlockerSource: String = ""

    let configStorage: ConfigurationStoring

    private init(configStorage: ConfigurationStoring = DefaultConfigurationStorage.shared) {
        self.configStorage = configStorage
        reload()
    }

    func reload() {
        contentBlockerRulesSource = buildContentBlockerRulesSource()
        contentBlockerSource = buildContentBlockerSource()
    }

    private func buildContentBlockerRulesSource() -> String {
        let unprotectedDomains = configStorage.loadData(for: .temporaryUnprotectedSites)?.utf8String() ?? ""
        return Self.loadJS("contentblockerrules", withReplacements: [
            "${unprotectedDomains}": unprotectedDomains
        ])
    }

    private func buildContentBlockerSource() -> String {

        // Use sensible defaults in case the upstream data is unparsable
        let trackerData = TrackerRadarManager.shared.encodedTrackerData ?? "{}"
        let surrogates = configStorage.loadData(for: .surrogates)?.utf8String() ?? ""
        let unprotectedSites = configStorage.loadData(for: .temporaryUnprotectedSites)?.utf8String() ?? ""

        return Self.loadJS("contentblocker", withReplacements: [
            "${unprotectedDomains}": unprotectedSites,
            "${trackerData}": trackerData,
            "${surrogates}": surrogates
        ])
    }

    static func loadJS(_ jsFile: String, withReplacements replacements: [String: String] = [:]) -> String {

        let bundle = Bundle.main
        let path = bundle.path(forResource: jsFile, ofType: "js")!

        guard var js = try? String(contentsOfFile: path) else {
            fatalError("Failed to load JavaScript \(jsFile) from \(path)")
        }

        for (key, value) in replacements {
            js = js.replacingOccurrences(of: key, with: value, options: .literal)
        }

        return js
    }

}
