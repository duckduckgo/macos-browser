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

class DefaultConfigurationStorage: ConfigurationStoring {

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

    @UserDefaultsWrapper(key: .configStorageTempUnprotectedSitesEtag, defaultValue: nil)
    private var temporaryUnprotectedSitesEtag: String?

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

        case .temporaryUnprotectedSites:
            return temporaryUnprotectedSitesEtag

        case .trackerRadar:
            return trackerRadarEtag
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

        case .temporaryUnprotectedSites:
            temporaryUnprotectedSitesEtag = etag

        case .trackerRadar:
            trackerRadarEtag = etag
        }
    }

    func loadData(for config: ConfigurationLocation) -> Data? {
        print("***", #function, config.rawValue)
        let file = FileManager.default.fileUrl(for: config)
        let data = try? Data(contentsOf: file)
        print("***", #function, config.rawValue, data?.count ?? -1)
        return data
    }

    func saveData(_ data: Data, for config: ConfigurationLocation) throws {
        let file = FileManager.default.fileUrl(for: config)
        try data.write(to: file, options: .atomic)
    }

    func log() {
        os_log("bloomFilterBinaryEtag %{public}s", type: .default, bloomFilterBinaryEtag ?? "")
        os_log("bloomFilterSpecEtag %{public}s", type: .default, bloomFilterSpecEtag ?? "")
        os_log("bloomFilterExcludedDomainsEtag %{public}s", type: .default, bloomFilterExcludedDomainsEtag ?? "")
        os_log("surrogatesEtag %{public}s", type: .default, surrogatesEtag ?? "")
        os_log("temporaryUnprotectedSitesEtag %{public}s", type: .default, temporaryUnprotectedSitesEtag ?? "")
        os_log("trackerRadarEtag %{public}s", type: .default, trackerRadarEtag ?? "")
    }

}

fileprivate extension FileManager {

    private static let fileLocations: [ConfigurationLocation: String] = [
        .bloomFilterBinary: "smarterEncryption.bin",
        .bloomFilterExcludedDomains: "smarterEncryptionExclusions.bin",
        .bloomFilterSpec: "smarterEncryption.spec",
        .surrogates: "surrogates.txt",
        .temporaryUnprotectedSites: "temp-unprotected-sites.txt",
        .trackerRadar: "tracker-radar.json"
    ]

    func fileUrl(for config: ConfigurationLocation) -> URL {
        guard let dir = urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could  not find application support directory")
        }
        return dir.appendingPathComponent(Self.fileLocations[config]!)
    }

}
