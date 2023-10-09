//
//  NetworkExtensionControllerThroughSession.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import SystemExtensions
import NetworkProtectionUI

/// Network Protection's network extension session object.
///
/// Through this class the app that owns the VPN can interact with the network extension.
///
final class NetworkExtensionController {

    private let systemExtensionManager: SystemExtensionManager

    init(extensionBundleID: String) {
        systemExtensionManager = SystemExtensionManager(extensionBundleID: extensionBundleID)
    }

    private func sendProviderMessage() {
        
    }
}

extension NetworkExtensionController {
    func activateSystemExtension(waitingForUserApproval: @escaping () -> Void) async throws {
        try await systemExtensionManager.activate(
            waitingForUserApproval: waitingForUserApproval)

        try? await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)
    }

    func deactivateSystemExtension() async throws {
        do {
            try await systemExtensionManager.deactivate()
        } catch OSSystemExtensionError.extensionNotFound {
            // This is an intentional no-op to silence this type of error
            // since on deactivation this is ok.
        } catch {
            throw error
        }
    }
}
