//
//  NetworkExtensionController.swift
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
import NetworkProtection
import NetworkProtectionUI

#if NETP_SYSTEM_EXTENSION
import SystemExtensionManager
import SystemExtensions
#endif

/// The VPN's network extension session object.
///
/// Through this class the app that owns the VPN can interact with the network extension.
///
final class NetworkExtensionController {

#if NETP_SYSTEM_EXTENSION
    private let systemExtensionManager: SystemExtensionManager
    private let defaults: UserDefaults
#endif

    init(extensionBundleID: String, defaults: UserDefaults = .netP) {
#if NETP_SYSTEM_EXTENSION
        systemExtensionManager = SystemExtensionManager(extensionBundleID: extensionBundleID)
        self.defaults = defaults
#endif
    }

}

extension NetworkExtensionController {

    func activateSystemExtension(waitingForUserApproval: @escaping () -> Void) async throws {
#if NETP_SYSTEM_EXTENSION
        if let extensionVersion = try await systemExtensionManager.activate(waitingForUserApproval: waitingForUserApproval) {

            NetworkProtectionLastVersionRunStore(userDefaults: defaults).lastExtensionVersionRun = extensionVersion
        }

        try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)
#endif
    }

    func deactivateSystemExtension() async throws {
#if NETP_SYSTEM_EXTENSION
        do {
            try await systemExtensionManager.deactivate()
        } catch OSSystemExtensionError.extensionNotFound {
            // This is an intentional no-op to silence this type of error
            // since on deactivation this is ok.
        } catch {
            throw error
        }
#endif
    }

}
