//
//  ConfigurationStore.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import os.log
import BrowserServicesKit
import Persistence
import Common
import Configuration
import PixelKit

final class ConfigurationStore: ConfigurationStoring {

    private static let fileLocations: [Configuration: String] = [
        .privacyConfiguration: "macos-config.json",
    ]

    enum Error: Swift.Error {

        case unsupportedConfig

        func withUnderlyingError(_ underlyingError: Swift.Error) -> Swift.Error {
            let nsError = self as NSError
            return NSError(domain: nsError.domain, code: nsError.code, userInfo: [NSUnderlyingErrorKey: underlyingError])
        }

    }

    private var privacyConfigurationEtagKey: String {
        return "configurationPrivacyConfigurationEtag"
    }

    let defaults: KeyValueStoring

    var privacyConfigurationEtag: String? {
        get {
            defaults.object(forKey: privacyConfigurationEtagKey) as? String
        }
        set {
            defaults.set(newValue, forKey: privacyConfigurationEtagKey)
        }
    }

    init(defaults: KeyValueStoring = UserDefaults.config) {
        self.defaults = defaults
    }

    func log() {
        Logger.config.log("privacyConfigurationEtag \(self.privacyConfigurationEtag ?? "", privacy: .public)")
    }

    func loadData(for config: Configuration) -> Data? {
        let file = fileUrl(for: config)
        var data: Data?
        var coordinatorError: NSError?

        NSFileCoordinator().coordinate(readingItemAt: file, error: &coordinatorError) { fileUrl in
            do {
                data = try Data(contentsOf: fileUrl)
            } catch {
                let nserror = error as NSError

                if nserror.domain != NSCocoaErrorDomain || nserror.code != NSFileReadNoSuchFileError {
                    PixelKit.fire(DebugEvent(DataBrokerProtectionPixels.errorLoadingCachedConfig(error)))
                }
            }
        }

        if let coordinatorError {
            Logger.config.error("Unable to read \(config.rawValue, privacy: .public): \(coordinatorError.localizedDescription, privacy: .public)")
        }

        return data
    }

    func loadEtag(for configuration: Configuration) -> String? {
        guard configuration == .privacyConfiguration else { return nil }

        return privacyConfigurationEtag
    }

    func loadEmbeddedEtag(for configuration: Configuration) -> String? {
        // If we embed the full config some day we need to load the etag for it here
        return nil
    }

    func saveData(_ data: Data, for configuration: Configuration) throws {
        guard configuration == .privacyConfiguration else { throw Error.unsupportedConfig }
        let file = fileUrl(for: configuration)
        var coordinatorError: NSError?

        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &coordinatorError) { fileUrl in
            do {
                try data.write(to: fileUrl, options: .atomic)
            } catch {
                Logger.config.error("Unable to write \(configuration.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if let coordinatorError {
            Logger.config.error("Unable to write \(configuration.rawValue, privacy: .public): \(coordinatorError.localizedDescription, privacy: .public)")
        }
    }

    func saveEtag(_ etag: String, for configuration: Configuration) throws {
        guard configuration == .privacyConfiguration else { throw Error.unsupportedConfig }

        privacyConfigurationEtag = etag
    }

    func fileUrl(for config: Configuration) -> URL {
        let fm = FileManager.default

        guard let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.configAppGroup) else {
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
