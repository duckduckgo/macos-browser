//
//  BWInstallationService.swift
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

enum BWInstallationState {

    case notInstalled
    case oldVersion
    case incompatible
    case installed

}

protocol BWInstallationService {

    var installationState: BWInstallationState { get }
    var isIntegrationWithDuckDuckGoEnabled: Bool { get }

    func openBitwarden()

}

final class LocalBitwardenInstallationService: BWInstallationService {

    static var bundlePath = "/Applications/Bitwarden.app"
    private lazy var bundleUrl = URL(fileURLWithPath: Self.bundlePath)
    static var minimumVersion = "2022.10.1"
    static var incompatibleVersions = ["2024.3.0", "2024.3.2", "2024.4.0", "2024.4.1", "2024.10.0", "2024.10.1", "2024.10.2"]

    private lazy var manifestPath: String = {
#if DEBUG
        // Even if debugging or developing, look at the standard location of the manifest file
        let sandboxPathComponent = "Containers/com.duckduckgo.macos.browser/Data/Library/Application Support/"
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let applicationSupport = libraryURL.appendingPathComponent(sandboxPathComponent)
#else
        let applicationSupport = URL.sandboxApplicationSupportURL
#endif
        return applicationSupport.appendingPathComponent("NativeMessagingHosts/com.8bit.bitwarden.json").path
    }()

    private lazy var sandboxDataFileUrl: URL = {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let bitwardenPathComponent = "Containers/com.bitwarden.desktop/Data/Library/Application Support/Bitwarden/data.json"
        return libraryURL.appendingPathComponent(bitwardenPathComponent)
    }()

    private lazy var dataFileUrl: URL = {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let bitwardenPathComponent = "Application Support/Bitwarden/data.json"
        return libraryURL.appendingPathComponent(bitwardenPathComponent)
    }()

    var installationState: BWInstallationState {
        guard let version = ApplicationVersionReader.getVersion(of: Self.bundlePath) else {
            return .notInstalled
        }

        guard Self.minimumVersion.compare(version, options: .numeric) != .orderedDescending else {
            return .oldVersion
        }

        guard !Self.incompatibleVersions.contains(version) else {
            return .incompatible
        }

        return .installed
    }

    var isSandboxContainerAccessApproved: Bool {
        if FileManager.default.fileExists(atPath: sandboxDataFileUrl.path) {
            return FileManager.default.isReadableFile(atPath: sandboxDataFileUrl.path)
        }

        // User installed the DMG version which doesn't require an approval
        return true
    }

    var isIntegrationWithDuckDuckGoEnabled: Bool {
        // Select correct data file and check the integration setting
        let isIntegrationInSandboxDataFileEnabled = isIntegrationEnabled(in: sandboxDataFileUrl)
        let isIntegrationInDataFileEnabled = isIntegrationEnabled(in: dataFileUrl)
        let sandboxDataFileModificationDate = getModificationDate(for: sandboxDataFileUrl)
        let dataFileModificationDate = getModificationDate(for: dataFileUrl)

        let isIntegrationEnabled: Bool
        if let sandboxDataFileModificationDate = sandboxDataFileModificationDate {
            if let dataFileModificationDate = dataFileModificationDate {
                if dataFileModificationDate > sandboxDataFileModificationDate {
                    isIntegrationEnabled = isIntegrationInDataFileEnabled
                } else {
                    isIntegrationEnabled = isIntegrationInSandboxDataFileEnabled
                }
            } else {
                isIntegrationEnabled = isIntegrationInSandboxDataFileEnabled
            }
        } else {
            if dataFileModificationDate != nil {
                isIntegrationEnabled = isIntegrationInSandboxDataFileEnabled
            } else {
                isIntegrationEnabled = false
            }
        }

        // Check for the existence of manifest file. It is a correct way to detect that integration
        // with DuckDuckGo is enabled. Unfortunately, Bitwarden installed though App Store can't
        // create manifest file (sandbox)
        let manifestExists = FileManager.default.fileExists(atPath: manifestPath)

        return manifestExists || isIntegrationEnabled
    }

    private func isIntegrationEnabled(in dataFileURL: URL) -> Bool {
        do {
            let dataFile = try String(contentsOf: dataFileURL)
            return dataFile.range(of: "enableDuckDuckGoBrowserIntegration\": true") != nil
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
