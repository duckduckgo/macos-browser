//
//  BitwardenInstallationService.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import AppKit
import os.log

protocol BitwardenInstallationService {
    
    var isBitwardenInstalled: Bool { get }
    var isIntegrationWithDuckDuckGoEnabled: Bool { get }

    func openBitwarden()

}

final class LocalBitwardenInstallationService: BitwardenInstallationService {

    private lazy var bundlePath = "/Applications/Bitwarden.app"
    private lazy var bundleUrl = URL(fileURLWithPath: bundlePath)

    private lazy var manifestPath: String = {
#if DEBUG

        let sandboxPathComponent = "Containers/com.duckduckgo.macos.browser/Data/Library/Application Support/"
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let applicationSupport = libraryURL.appendingPathComponent(sandboxPathComponent)
#else
        let applicationSupport = URL.sandboxApplicationSupportURL
#endif
        return applicationSupport            .appendingPathComponent("NativeMessagingHosts/com.8bit.bitwarden.json")
            .path
    }()

    private lazy var sandboxDataFileUrl : URL = {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let bitwardenPathComponent = "Containers/com.bitwarden.desktop/Data/Library/Application Support/Bitwarden/data.json"
        return libraryURL.appendingPathComponent(bitwardenPathComponent)
    }()

    private lazy var dataFileUrl: URL = {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let bitwardenPathComponent = "Application Support/Bitwarden/data.json"
        return libraryURL.appendingPathComponent(bitwardenPathComponent)
    }()

    var isBitwardenInstalled: Bool {
        return FileManager.default.fileExists(atPath: bundlePath)
    }

    var isIntegrationWithDuckDuckGoEnabled: Bool {
        let isIntegrationInSandboxDataFileEnabled = isIntegrationEnabled(in: sandboxDataFileUrl)
        os_log("LocalBitwardenInstallationService: Sandbox data file: enableDuckDuckGoBrowserIntegration: %{public}s", log: .bitwarden, type: .default, isIntegrationInSandboxDataFileEnabled.description)
        let isIntegrationInDataFileEnabled = isIntegrationEnabled(in: dataFileUrl)
        os_log("LocalBitwardenInstallationService: Standard data file: enableDuckDuckGoBrowserIntegration: %{public}s", log: .bitwarden, type: .default, isIntegrationInDataFileEnabled.description)
        let sandboxDataFileModificationDate = getModificationDate(for: sandboxDataFileUrl)
        let dataFileModificationDate = getModificationDate(for: dataFileUrl)

        let isIntegrationEnabled: Bool
        if let sandboxDataFileModificationDate = sandboxDataFileModificationDate {
            if let dataFileModificationDate = dataFileModificationDate {
                if dataFileModificationDate > sandboxDataFileModificationDate {
                    os_log("LocalBitwardenInstallationService: Using standard data file", log: .bitwarden, type: .default)
                    isIntegrationEnabled = isIntegrationInDataFileEnabled
                } else {
                    os_log("LocalBitwardenInstallationService: Using sandbox data file", log: .bitwarden, type: .default)
                    isIntegrationEnabled = isIntegrationInSandboxDataFileEnabled
                }
            } else {
                os_log("LocalBitwardenInstallationService: Using sandbox data file", log: .bitwarden, type: .default)
                isIntegrationEnabled = isIntegrationInSandboxDataFileEnabled
            }
        } else {
            if dataFileModificationDate != nil {
                os_log("LocalBitwardenInstallationService: Using sandbox data file", log: .bitwarden, type: .default)
                isIntegrationEnabled = isIntegrationInSandboxDataFileEnabled
            } else {
                isIntegrationEnabled = false
            }
        }

        // Check for the existence of manifest file. (Not working for Bitwarden installed from App Store)
        let manifestExists = FileManager.default.fileExists(atPath: manifestPath)
        os_log("LocalBitwardenInstallationService: Is manifest available: %{public}s", log: .bitwarden, type: .default, manifestExists.description)

        return manifestExists || isIntegrationEnabled
    }

    private func isIntegrationEnabled(in dataFileURL: URL) -> Bool {
        do {
            let dataFile = try String(contentsOf: dataFileURL)
            return dataFile.range(of: "\"enableDuckDuckGoBrowserIntegration\": true") != nil
        } catch {
            return false
        }
    }

    private func getModificationDate(for dataFileURL: URL) -> Date? {
        return try? FileManager.default.attributesOfItem(atPath: dataFileURL.path)[FileAttributeKey.modificationDate] as? Date
    }
    
    func openBitwarden() {
        NSWorkspace.shared.open(bundleUrl)
    }
    
}
