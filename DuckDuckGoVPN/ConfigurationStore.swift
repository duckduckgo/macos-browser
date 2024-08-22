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

    static let shared = ConfigurationStore()
    let defaults = UserDefaults.netP

    var privacyConfigurationEtag: String? {
        get {
            defaults.string(forKey: privacyConfigurationEtagKey)
        }
        set {
            defaults.setValue(newValue, forKey: privacyConfigurationEtagKey)
        }
    }

    func log() {
        Logger.config.log("privacyConfigurationEtag \(self.privacyConfigurationEtag ?? "", privacy: .public)")
    }

    func loadData(for configuration: Configuration) -> Data? {
        guard configuration == .privacyConfiguration else { return nil }

        let file = fileUrl(for: configuration)
        do {
            return try Data(contentsOf: file)
        } catch {
            PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionConfigurationErrorLoadingCachedConfig(error))
            return nil
        }
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
        try data.write(to: file, options: .atomic)
    }

    func saveEtag(_ etag: String, for configuration: Configuration) throws {
        guard configuration == .privacyConfiguration else { throw Error.unsupportedConfig }

        privacyConfigurationEtag = etag
    }

    func fileUrl(for config: Configuration) -> URL {
        let fm = FileManager.default

        guard let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier!) else { // TODO: Change to Configuration group
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
