//
//  ConfigurationStore.swift
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

import Common
import os.log
import Foundation
import Configuration
import Persistence
import PixelKit

final class ConfigurationStore: ConfigurationStoring {

    private static let fileLocations: [Configuration: String] = [
        .bloomFilterBinary: "smarterEncryption.bin",
        .bloomFilterExcludedDomains: "smarterEncryptionExclusions.json",
        .bloomFilterSpec: "smarterEncryptionSpec.json",
        .surrogates: "surrogates.txt",
        .privacyConfiguration: "macos-config.json",
        .trackerDataSet: "tracker-radar.json",
        .FBConfig: "social_ctp_configuration.json",
        .remoteMessagingConfig: "remote-messaging-config.json"
    ]

    private enum Constants {
        static let configStorageTrackerRadarEtag = "config.storage.trackerradar.etag"
        static let configStorageBloomFilterSpecEtag = "config.storage.bloomfilter.spec.etag"
        static let configStorageBloomFilterBinaryEtag = "config.storage.bloomfilter.binary.etag"
        static let configStorageBloomFilterExclusionsEtag = "config.storage.bloomfilter.exclusions.etag"
        static let configStorageSurrogatesEtag = "config.storage.surrogates.etag"
        static let configStoragePrivacyConfigurationEtag = "config.storage.privacyconfiguration.etag"
        static let configFBConfigEtag = "config.storage.fbconfig.etag"
        static let configStorageRemoteMessagingConfigEtag = "config.storage.remotemessagingconfig.etag"
    }

    static let shared = ConfigurationStore()
    private let defaults: KeyValueStoring

    private var trackerRadarEtag: String? {
        get {
            defaults.object(forKey: Constants.configStorageTrackerRadarEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configStorageTrackerRadarEtag)
        }
    }

    private var bloomFilterSpecEtag: String? {
        get {
            defaults.object(forKey: Constants.configStorageBloomFilterSpecEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configStorageBloomFilterSpecEtag)
        }
    }

    private var bloomFilterBinaryEtag: String? {
        get {
            defaults.object(forKey: Constants.configStorageBloomFilterBinaryEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configStorageBloomFilterBinaryEtag)
        }
    }

    private var bloomFilterExcludedDomainsEtag: String? {
        get {
            defaults.object(forKey: Constants.configStorageBloomFilterExclusionsEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configStorageBloomFilterExclusionsEtag)
        }
    }

    private var surrogatesEtag: String? {
        get {
            defaults.object(forKey: Constants.configStorageSurrogatesEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configStorageSurrogatesEtag)
        }
    }

    private var privacyConfigurationEtag: String? {
        get {
            defaults.object(forKey: Constants.configStoragePrivacyConfigurationEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configStoragePrivacyConfigurationEtag)
        }
    }

    private var FBConfigEtag: String? {
        get {
            defaults.object(forKey: Constants.configFBConfigEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configFBConfigEtag)
        }
    }

    private var remoteMessagingConfigEtag: String? {
        get {
            defaults.object(forKey: Constants.configStorageRemoteMessagingConfigEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Constants.configStorageRemoteMessagingConfigEtag)
        }
    }

    init(defaults: KeyValueStoring = UserDefaults.appConfiguration) {
        self.defaults = defaults
    }

    func loadEtag(for configuration: Configuration) -> String? {
        switch configuration {
        case .bloomFilterSpec: return bloomFilterSpecEtag
        case .bloomFilterBinary: return bloomFilterBinaryEtag
        case .bloomFilterExcludedDomains: return bloomFilterExcludedDomainsEtag
        case .surrogates: return surrogatesEtag
        case .trackerDataSet: return trackerRadarEtag
        case .privacyConfiguration: return privacyConfigurationEtag
        case .FBConfig: return FBConfigEtag
        case .remoteMessagingConfig: return remoteMessagingConfigEtag
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
        case .remoteMessagingConfig: remoteMessagingConfigEtag = etag
        }
    }

    func loadData(for config: Configuration) -> Data? {
        let file = fileUrl(for: config)
        var data: Data?
        var coordinatorError: NSError?

        NSFileCoordinator().coordinate(readingItemAt: file, error: &coordinatorError) { fileUrl in
            do {
                data = try Data(contentsOf: fileUrl)
            } catch {
                guard NSApp.runType.requiresEnvironment else { return }

                let nserror = error as NSError

                if nserror.domain != NSCocoaErrorDomain || nserror.code != NSFileReadNoSuchFileError {
                    PixelKit.fire(DebugEvent(GeneralPixel.trackerDataCouldNotBeLoaded, error: error))
                }
            }
        }

        if let coordinatorError {
            // TODO: Fire pixel
            Logger.config.error("Unable to read \(config.rawValue, privacy: .public): \(coordinatorError.localizedDescription, privacy: .public)")
        }

        return data
    }

    func saveData(_ data: Data, for config: Configuration) throws {
        let file = fileUrl(for: config)
        var coordinatorError: NSError?

        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &coordinatorError) { fileUrl in
            do {
                try data.write(to: fileUrl, options: .atomic)
            } catch {
                Logger.config.error("Unable to write \(config.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if let coordinatorError {
            Logger.config.error("Unable to write \(config.rawValue, privacy: .public): \(coordinatorError.localizedDescription, privacy: .public)")
        }
    }

    func log() {
        Logger.config.log("bloomFilterBinaryEtag \(self.bloomFilterBinaryEtag ?? "", privacy: .public)")
        Logger.config.log("bloomFilterSpecEtag \(self.bloomFilterSpecEtag ?? "", privacy: .public)")
        Logger.config.log("bloomFilterExcludedDomainsEtag \(self.bloomFilterExcludedDomainsEtag ?? "", privacy: .public)")
        Logger.config.log("surrogatesEtag \(self.surrogatesEtag ?? "", privacy: .public)")
        Logger.config.log("trackerRadarEtag \(self.trackerRadarEtag ?? "", privacy: .public)")
        Logger.config.log("privacyConfigurationEtag \(self.privacyConfigurationEtag ?? "", privacy: .public)")
        Logger.config.log("FBConfigEtag \(self.FBConfigEtag ?? "", privacy: .public)")
        Logger.config.log("remoteMessagingConfig \(self.remoteMessagingConfigEtag ?? "", privacy: .public)")
    }

    func fileUrl(for config: Configuration) -> URL {
        let fm = FileManager.default

        guard let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.appGroup(bundle: .appConfiguration)) else {
            fatalError("Failed to get application group URL")
        }
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
