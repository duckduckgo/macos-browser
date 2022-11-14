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

protocol BitwardenInstallationService {
    
    var isBitwardenInstalled: Bool { get }
    var isIntegrationWithDuckDuckGoEnabled: Bool { get }

    func openBitwarden()

}

final class LocalBitwardenInstallationService: BitwardenInstallationService {

    private lazy var bitwardenBundlePath = "/Applications/Bitwarden.app"
    private lazy var bitwardenUrl = URL(fileURLWithPath: bitwardenBundlePath)

    private lazy var bitwardenManifestPath: String = {
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

    private lazy var bitwardenDataFileUrl: URL = {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let bitwardenPathComponent = "Containers/com.bitwarden.desktop/Data/Library/Application Support/Bitwarden/data.json"
        return libraryURL.appendingPathComponent(bitwardenPathComponent)
    }()

    var isBitwardenInstalled: Bool {
        return FileManager.default.fileExists(atPath: bitwardenBundlePath)
    }

    var isIntegrationWithDuckDuckGoEnabled: Bool {
        let integrationEnabledInSettingsFile: Bool
        do {
            let dataFile = try String(contentsOf: bitwardenDataFileUrl)
            integrationEnabledInSettingsFile = dataFile.range(of: "\"enableDuckDuckGoBrowserIntegration\": true") != nil
        } catch {
            integrationEnabledInSettingsFile = false
            return false
        }

        // Older implementation not working with Bitwarden installed from App Store
        let integrationFileAvailable = FileManager.default.fileExists(atPath: bitwardenManifestPath)
        return integrationEnabledInSettingsFile || integrationFileAvailable
    }
    
    func openBitwarden() {
        NSWorkspace.shared.open(bitwardenUrl)
    }
    
}
