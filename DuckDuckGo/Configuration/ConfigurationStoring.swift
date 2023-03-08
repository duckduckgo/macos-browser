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

protocol ConfigurationStoring {

    func loadData(for: ConfigurationLocation) -> Data?
    func loadEtag(for: ConfigurationLocation) -> String?
    func saveData(_ data: Data, for: ConfigurationLocation) throws
    func saveEtag(_ etag: String, for: ConfigurationLocation) throws
    func log()

}

final class DefaultConfigurationStorage: ConfigurationStoring {

    private static let fileLocations: [ConfigurationLocation: String] = [
        .bloomFilterBinary: "smarterEncryption.bin",
        .bloomFilterExcludedDomains: "smarterEncryptionExclusions.json",
        .bloomFilterSpec: "smarterEncryptionSpec.json",
        .surrogates: "surrogates.txt",
        .privacyConfiguration: "macos-config.json",
        .trackerRadar: "tracker-radar.json",
        .FBConfig: "social_ctp_configuration.json"
    ]

    static let shared = DefaultConfigurationStorage()

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

    func loadEtag(for config: ConfigurationLocation) -> String? {
        switch config {
        case .bloomFilterSpec:
            return bloomFilterSpecEtag

        case .bloomFilterBinary:
            return bloomFilterBinaryEtag

        case .bloomFilterExcludedDomains:
            return bloomFilterExcludedDomainsEtag

        case .surrogates:
            return surrogatesEtag

        case .trackerRadar:
            return trackerRadarEtag

        case .privacyConfiguration:
            return privacyConfigurationEtag

        case .FBConfig:
            return FBConfigEtag
        }
    }

    func saveEtag(_ etag: String, for config: ConfigurationLocation) throws {
        switch config {
        case .bloomFilterSpec:
            bloomFilterSpecEtag = etag

        case .bloomFilterBinary:
            bloomFilterBinaryEtag = etag

        case .bloomFilterExcludedDomains:
            bloomFilterExcludedDomainsEtag = etag

        case .surrogates:
            surrogatesEtag = etag

        case .trackerRadar:
            trackerRadarEtag = etag

        case .privacyConfiguration:
            privacyConfigurationEtag = etag

        case .FBConfig:
            return FBConfigEtag = etag
        }
    }

    func loadData(for config: ConfigurationLocation) -> Data? {
        let file = fileUrl(for: config)
        do {
            return try Data(contentsOf: file)
        } catch {
            guard !NSApp.isRunningUnitTests else { return nil }

            Pixel.fire(.debug(event: .trackerDataCouldNotBeLoaded, error: error))
            return nil
        }
    }

    func saveData(_ data: Data, for config: ConfigurationLocation) throws {
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

    func fileUrl(for config: ConfigurationLocation) -> URL {
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
