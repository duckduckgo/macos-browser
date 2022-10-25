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

protocol BitwardenInstallationManager {
    
    var isBitwardenInstalled: Bool { get }
    
    func openBitwarden()

}

final class LocalBitwardenInstallationManager: BitwardenInstallationManager {

    private lazy var bitwardenBundlePath = "/Applications/Bitwarden.app"
    private lazy var bitwardenUrl = URL(fileURLWithPath: bitwardenBundlePath)

    var isBitwardenInstalled: Bool {
        return FileManager.default.fileExists(atPath: bitwardenBundlePath)
    }


    var bitwardenManifestPath: String {
#if DEBUG

        let sandboxPathComponent = "Containers/com.duckduckgo.macos.browser/Data/Library/Application Support/"
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let applicationSupport = libraryURL.appendingPathComponent(sandboxPathComponent)
#else
        let applicationSupport = URL.sandboxApplicationSupportURL
#endif
        return applicationSupport            .appendingPathComponent("NativeMessagingHosts/com.8bit.bitwarden.json")
            .path
    }


    var isIntegrationWithDuckDuckGoEnabled: Bool {
        return FileManager.default.fileExists(atPath: bitwardenManifestPath)
    }
    
    func openBitwarden() {
        NSWorkspace.shared.open(bitwardenUrl)
    }
    
}
