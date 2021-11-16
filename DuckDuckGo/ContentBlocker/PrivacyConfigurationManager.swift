//
//  PrivacyConfigurationManager.swift
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
import TrackerRadarKit
import Combine

protocol PrivacyConfigurationManagment {
    
    var tempUnprotectedDomains: [String] { get }
    
    func isEnabled(featureKey: PrivacyConfiguration.SupportedFeatures) -> Bool
    func exceptionsList(forFeature featureKey: PrivacyConfiguration.SupportedFeatures) -> [String]
    func webCompatLookup() -> [String: String]
}

final class PrivacyConfigurationManager {

    struct Constants {
        static let embeddedDataSetETag = "e6214cfd463faa4d9d00ab357539aa43"
    }

    enum DataSet {

        case embedded
        case embeddedFallback
        case downloaded

    }

    static let shared = PrivacyConfigurationManager()

    private(set) var config: PrivacyConfiguration
    private(set) var encodedConfigData: String

    private var configDataStore: ConfigurationStoring

    init(configDataStore: ConfigurationStoring = DefaultConfigurationStorage.shared) {
        self.configDataStore = configDataStore
        (self.config, self.encodedConfigData, _) = Self.loadData()
    }

    private typealias LoadDataResult = (PrivacyConfiguration, String, DataSet)
    private class func loadData() -> LoadDataResult {

        var dataSet: DataSet
        let configData: PrivacyConfiguration
        var data: Data
/*
        if let loadedData = DefaultConfigurationStorage.shared.loadData(for: .privacyConfiguration) {
            data = loadedData
            dataSet = .downloaded
        } else {
 */
            data = loadEmbeddedAsData()
            dataSet = .embedded
   //     }

        do {
            // This might fail if the downloaded data is corrupt or format has changed unexpectedly
            configData = try JSONDecoder().decode(PrivacyConfiguration.self, from: data)
        } catch {
            // This should NEVER fail
            data = loadEmbeddedAsData()
            configData = (try? JSONDecoder().decode(PrivacyConfiguration.self, from: data))!
            dataSet = .embeddedFallback

            Pixel.fire(.debug(event: .privacyConfigurationParseFailed, error: error))
        }

        return (configData, data.utf8String()!, dataSet)
    }

    @discardableResult
    public func reload() -> DataSet {
        let (configData, encodedConfigData, dataSet) = Self.loadData()
        if Thread.isMainThread {
            self.config = configData
            self.encodedConfigData = encodedConfigData
        } else {
            DispatchQueue.main.async {
                self.config = configData
                self.encodedConfigData = encodedConfigData
            }
        }

        if dataSet != .downloaded {
            Pixel.fire(.debug(event: .privacyConfigurationReloadFailed))
        }

        return dataSet
    }

    static var embeddedUrl: URL {
        return Bundle.main.url(forResource: "macos-config", withExtension: "json")!
    }

    static func loadEmbeddedAsData() -> Data {
        let json = try? Data(contentsOf: embeddedUrl)
        return json!
    }

    static func loadEmbeddedAsString() -> String {
        let json = try? String(contentsOf: embeddedUrl, encoding: .utf8)
        return json!
    }

}

extension PrivacyConfigurationManager: PrivacyConfigurationManagment {
    
    enum ConfigurationSettingsKeys: String {
        case gpcHeaderEnabled = "gpcHeaderEnabledSites"
        case webCompatScripts = "loadScripts"
    }
    
    var tempUnprotectedDomains: [String] {
        return config.tempUnprotectedDomains
    }
    
    func isEnabled(featureKey: PrivacyConfiguration.SupportedFeatures) -> Bool {
        return config.isEnabled(featureKey: featureKey)
    }
    
    func exceptionsList(forFeature featureKey: PrivacyConfiguration.SupportedFeatures) -> [String] {
        return config.exceptionsList(forFeature: featureKey)
    }
    
    func gpcHeadersEnabled() -> [String] {
        guard let enabledSites = config.features[PrivacyConfiguration.SupportedFeatures.gpc.rawValue]?
                .settings?[ConfigurationSettingsKeys.gpcHeaderEnabled.rawValue] as? [String] else { return [] }
        
        return enabledSites
    }
    
    func webCompatLookup() -> [String: String] {
        guard let webCompatScripts = config.features[PrivacyConfiguration.SupportedFeatures.webCompat.rawValue]?
                .settings?[ConfigurationSettingsKeys.webCompatScripts.rawValue] as? [String: String] else { return [:] }
        
        return webCompatScripts
    }
}
