//
//  ConfigurationStoring.swift
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
import os
import Configuration

final class ConfigurationStore: ConfigurationStoring {

    private static let fileLocations: [Configuration: String] = [
        .bloomFilterBinary: "smarterEncryption.bin",
        .bloomFilterExcludedDomains: "smarterEncryptionExclusions.json",
        .bloomFilterSpec: "smarterEncryptionSpec.json",
        .surrogates: "surrogates.txt",
        .privacyConfiguration: "macos-config.json",
        .trackerDataSet: "tracker-radar.json",
        .FBConfig: "social_ctp_configuration.json"
    ]

    static let shared = ConfigurationStore()

    @UserDefaultsWrapper(key: .configStorageTrackerRadarEtag, defaultValue: nil)
    private var trackerRadarEtag: String?

    @UserDefaultsWrapper(key: .configStorageBloomFilterSpecEtag, defaultValue: nil)
    private var bloomFilterSpecEtag: String?

    @UserDefaultsWrapper(key: .configStorageBloomFilterBinaryEtag, defaultValue: nil)
    private var bloomFilterBinaryEtag: String?

    @UserDefaultsWrapper(key: .configStorageBloomFilterExclusionsEtag, defaultValue: nil)
    private var bloomFilterExcludedDomainsEtag: String?

    @UserDefaultsWrapper(key: .configStorageSurrogatesEtag, defaultValue: nil)
    private var surrogatesEtag: String?

    @UserDefaultsWrapper(key: .configStoragePrivacyConfigurationEtag, defaultValue: nil)
    private var privacyConfigurationEtag: String?

    @UserDefaultsWrapper(key: .configFBConfigEtag, defaultValue: nil)
    private var FBConfigEtag: String?

    private init() { }

    func loadEtag(for configuration: Configuration) -> String? {
        switch configuration {
        case .bloomFilterSpec: return bloomFilterSpecEtag
        case .bloomFilterBinary: return bloomFilterBinaryEtag
        case .bloomFilterExcludedDomains: return bloomFilterExcludedDomainsEtag
        case .surrogates: return surrogatesEtag
        case .trackerDataSet: return trackerRadarEtag
        case .privacyConfiguration: return privacyConfigurationEtag
        case .FBConfig: return FBConfigEtag
        }
    }

    func loadEmbeddedEtag(for configuration: Configuration) -> String? {
        switch configuration {
        case .trackerDataSet: return AppTrackerDataSetProvider.Constants.embeddedDataETag
        case .privacyConfiguration: return AppPrivacyConfigurationDataProvider.Constants.embeddedDataSHA
        default: return nil
        }
    }

    func saveEtag(_ etag: String, for configuration: Configuration) throws {
        switch configuration {
        case .bloomFilterSpec: bloomFilterSpecEtag = etag
        case .bloomFilterBinary: bloomFilterBinaryEtag = etag
        case .bloomFilterExcludedDomains: bloomFilterExcludedDomainsEtag = etag
        case .surrogates: surrogatesEtag = etag
        case .trackerDataSet: trackerRadarEtag = etag
        case .privacyConfiguration: privacyConfigurationEtag = etag
        case .FBConfig: FBConfigEtag = etag
        }
    }

    func loadData(for config: Configuration) -> Data? {
        let file = fileUrl(for: config)
        do {
            return try Data(contentsOf: file)
        } catch {
            guard !NSApp.isRunningUnitTests else { return nil }

            Pixel.fire(.debug(event: .trackerDataCouldNotBeLoaded, error: error))
            return nil
        }
    }

    func saveData(_ data: Data, for config: Configuration) throws {
        let file = fileUrl(for: config)
        try data.write(to: file, options: .atomic)
    }

    func log() {
        os_log("bloomFilterBinaryEtag %{public}s", log: .config, type: .default, bloomFilterBinaryEtag ?? "")
        os_log("bloomFilterSpecEtag %{public}s", log: .config, type: .default, bloomFilterSpecEtag ?? "")
        os_log("bloomFilterExcludedDomainsEtag %{public}s", log: .config, type: .default, bloomFilterExcludedDomainsEtag ?? "")
        os_log("surrogatesEtag %{public}s", log: .config, type: .default, surrogatesEtag ?? "")
        os_log("trackerRadarEtag %{public}s", log: .config, type: .default, trackerRadarEtag ?? "")
        os_log("privacyConfigurationEtag %{public}s", log: .config, type: .default, privacyConfigurationEtag ?? "")
        os_log("FBConfigEtag %{public}s", log: .config, type: .default, FBConfigEtag ?? "")
    }

    func fileUrl(for config: Configuration) -> URL {
        let fm = FileManager.default

        let dir = URL.sandboxApplicationSupportURL
        let subDir = dir.appendingPathComponent("Configuration")

        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: subDir.path, isDirectory: &isDir) {
            do {
                try fm.createDirectory(at: subDir, withIntermediateDirectories: true, attributes: nil)
                isDir = true
            } catch {
                fatalError("Failed to create directory at \(subDir.path)")
            }
        }

        if !isDir.boolValue {
            fatalError("Configuration folder at \(subDir.path) is not a directory")
        }

        return subDir.appendingPathComponent(Self.fileLocations[config]!)
    }

}
