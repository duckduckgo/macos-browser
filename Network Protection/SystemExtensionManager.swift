//
//  SystemExtensionManager.swift
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
import Cocoa
import SystemExtensions
import os.log

final class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {

    static let shared = SystemExtensionManager()

    private static let bundleID = "com.duckduckgo.macos.browser.network-protection.system-extension.extension"

    private let networkProtectionLog: OSLog = OSLog(subsystem: "DuckDuckGo Network Protection App", category: "NetP")

    func activate() {
        os_log("🔵 System Extension activate", log: networkProtectionLog, type: .error)
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: Self.bundleID, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }

    func deactivate() {
        let activationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: Self.bundleID, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }

    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        os_log("🔵 System Extension actionForReplacingExtension %@ %@", log: networkProtectionLog, type: .error, existing, ext)

        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        os_log("🔵 System Extension needsUserApproval", log: networkProtectionLog, type: .error)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        os_log("🔵 System Extension didFinishWithResult %{public}@", log: networkProtectionLog, type: .error, result.rawValue)
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        os_log("🔵 System Extension didFailWithError %{public}@", log: networkProtectionLog, type: .error, error.localizedDescription)
    }

}
