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
    
    func openBitwarden() -> Bool
    
}

final class LocalBitwardenInstallationManager: BitwardenInstallationManager {
    
    private let bitwardenBundleID = "com.bitwarden.desktop"
    private let expectedBitwardenURL = "/Applications/Bitwarden.app"

    /// Returns the URL of the Bitwarden app.
    private var bitwardenURL: URL? {
        return NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bitwardenBundleID)?.url
    }

    var isBitwardenInstalled: Bool {
        guard let detectedBitwardenURL = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bitwardenBundleID) else {
            return false
        }
        
        return detectedBitwardenURL == expectedBitwardenURL
    }
    
    func openBitwarden() -> Bool {
        guard let bitwardenURL = self.bitwardenURL else {
            return false
        }

        return NSWorkspace.shared.open(bitwardenURL)
    }
    
}
