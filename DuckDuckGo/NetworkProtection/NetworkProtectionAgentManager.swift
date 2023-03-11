//
//  NetworkProtectionAgentManager.swift
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

import ServiceManagement

/// Takes care of enabling and disabling the NetP agent app.
/// 
final class NetworkProtectionAgentManager {
    // private static let agentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.notifications" as CFString
    private static let resetDelay = 200
    static let current = NetworkProtectionAgentManager()

    static var agentBundleID: CFString {
#if DEBUG
        "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.notifications" as CFString
#else
        "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.notifications.debug" as CFString
#endif
    }

#if NETP_SYSTEM_EXTENSION
    func enable() {
        SMLoginItemSetEnabled(Self.agentBundleID, true)
    }
#else
    func enable() {
        // We'll only run an agent if NetP runs as a Network Extension.  This may change
        // if we decide to have the agent also handle the NetP status bar menu item.
    }
#endif

#if NETP_SYSTEM_EXTENSION
    func disable() {
        SMLoginItemSetEnabled(Self.agentBundleID, false)
    }
#else
    func disable() {
        // We'll only run an agent if NetP runs as a Network Extension.  This may change
        // if we decide to have the agent also handle the NetP status bar menu item.
    }
#endif

#if NETP_SYSTEM_EXTENSION
    func reset() async throws {
        disable()
        if #available(macOS 13, *) {
            try await Task.sleep(for: .milliseconds(Self.resetDelay))
        } else {
            try await Task.sleep(nanoseconds: UInt64(Self.resetDelay) * NSEC_PER_MSEC)
        }
        enable()
    }
#else
    func reset() async throws {
        // We'll only run an agent if NetP runs as a Network Extension.  This may change
        // if we decide to have the agent also handle the NetP status bar menu item.
    }
#endif
}
