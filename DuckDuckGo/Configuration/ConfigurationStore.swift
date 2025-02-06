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
import PixelExperimentKit

private extension Configuration {
    var fileName: String {
        switch self {
        case .bloomFilterBinary: "smarterEncryption.bin"
        case .bloomFilterExcludedDomains: "smarterEncryptionExclusions.json"
        case .bloomFilterSpec: "smarterEncryptionSpec.json"
        case .surrogates: "surrogates.txt"
        case .privacyConfiguration: "macos-config.json"
        case .trackerDataSet: "tracker-radar.json"
        case .remoteMessagingConfig: "remote-messaging-config.json"
        }
    }
}

final class ConfigurationStore: ConfigurationStoring {

    private enum Etag {
        static let configStorageTrackerRadarEtag = "config.storage.trackerradar.etag"
        static let configStorageBloomFilterSpecEtag = "config.storage.bloomfilter.spec.etag"
        static let configStorageBloomFilterBinaryEtag = "config.storage.bloomfilter.binary.etag"
        static let configStorageBloomFilterExclusionsEtag = "config.storage.bloomfilter.exclusions.etag"
        static let configStorageSurrogatesEtag = "config.storage.surrogates.etag"
        static let configStoragePrivacyConfigurationEtag = "config.storage.privacyconfiguration.etag"
        static let configStorageRemoteMessagingConfigEtag = "config.storage.remotemessagingconfig.etag"
    }

    private let defaults: KeyValueStoring

    private var trackerRadarEtag: String? {
        get {
            defaults.object(forKey: Etag.configStorageTrackerRadarEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Etag.configStorageTrackerRadarEtag)
        }
    }

    private var bloomFilterSpecEtag: String? {
        get {
            defaults.object(forKey: Etag.configStorageBloomFilterSpecEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Etag.configStorageBloomFilterSpecEtag)
        }
    }

    private var bloomFilterBinaryEtag: String? {
        get {
            defaults.object(forKey: Etag.configStorageBloomFilterBinaryEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Etag.configStorageBloomFilterBinaryEtag)
        }
    }

    private var bloomFilterExcludedDomainsEtag: String? {
        get {
            defaults.object(forKey: Etag.configStorageBloomFilterExclusionsEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Etag.configStorageBloomFilterExclusionsEtag)
        }
    }

    private var surrogatesEtag: String? {
        get {
            defaults.object(forKey: Etag.configStorageSurrogatesEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Etag.configStorageSurrogatesEtag)
        }
    }

    private var privacyConfigurationEtag: String? {
        get {
            defaults.object(forKey: Etag.configStoragePrivacyConfigurationEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Etag.configStoragePrivacyConfigurationEtag)
        }
    }

    private var remoteMessagingConfigEtag: String? {
        get {
            defaults.object(forKey: Etag.configStorageRemoteMessagingConfigEtag) as? String
        }
        set {
            defaults.set(newValue, forKey: Etag.configStorageRemoteMessagingConfigEtag)
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
                    if config == .trackerDataSet, let experimentName = TDSOverrideExperimentMetrics.activeTDSExperimentNameWithCohort {
                        let parameters = [
                            "experimentName": experimentName,
                            "etag": loadEtag(for: .trackerDataSet) ?? ""
                        ]
                        PixelKit.fire(DebugEvent(GeneralPixel.trackerDataCouldNotBeLoaded, error: error), withAdditionalParameters: parameters)
                    } else {
                        PixelKit.fire(DebugEvent(GeneralPixel.trackerDataCouldNotBeLoaded, error: error))
                    }
                }
            }
        }

        if let coordinatorError {
            PixelKit.fire(DebugEvent(GeneralPixel.configurationFileCoordinatorError, error: coordinatorError))
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
        Logger.config.info("bloomFilterBinaryEtag \(self.bloomFilterBinaryEtag ?? "", privacy: .public)")
        Logger.config.info("bloomFilterSpecEtag \(self.bloomFilterSpecEtag ?? "", privacy: .public)")
        Logger.config.info("bloomFilterExcludedDomainsEtag \(self.self.bloomFilterExcludedDomainsEtag ?? "", privacy: .public)")
        Logger.config.info("surrogatesEtag \(self.surrogatesEtag ?? "", privacy: .public)")
        Logger.config.info("trackerRadarEtag \(self.trackerRadarEtag ?? "", privacy: .public)")
        Logger.config.info("privacyConfigurationEtag \(self.privacyConfigurationEtag ?? "", privacy: .public)")
        Logger.config.info("remoteMessagingConfig \(self.remoteMessagingConfigEtag ?? "", privacy: .public)")
    }

    func fileUrl(for configuration: Configuration) -> URL {
        let dir = FileManager.default.configurationDirectory()
        return dir.appendingPathComponent(configuration.fileName)
    }

}
