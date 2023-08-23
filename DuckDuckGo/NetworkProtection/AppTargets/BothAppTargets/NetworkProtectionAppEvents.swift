//
//  NetworkProtectionAppEvents.swift
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

import Common
import Foundation

#if NETWORK_PROTECTION
import NetworkProtection

/// Implements the sequence of steps that Network Protection needs to execute when the App starts up.
///
@available(macOS 11.4, *)
final class NetworkProtectionAppEvents {

    /// Call this method when the app finishes launching, to run the startup logic for NetP.
    ///
    func applicationDidFinishLaunching() {
        let loginItemsManager = NetworkProtectionLoginItemsManager()
        let keychainStore = NetworkProtectionKeychainTokenStore()

        guard keychainStore.isFeatureActivated else {
            loginItemsManager.disableLoginItems()
            LocalPinningManager.shared.unpin(.networkProtection)
            return
        }

        restartNetworkProtectionIfVersionChanged(using: loginItemsManager)
        refreshNetworkProtectionServers()
    }

    private func restartNetworkProtectionIfVersionChanged(using loginItemsManager: NetworkProtectionLoginItemsManager) {
        let currentVersion = AppVersion.shared.versionNumber
        let versionStore = NetworkProtectionLastVersionRunStore()
        defer {
            versionStore.lastVersionRun = currentVersion
        }

        // should‘ve been run at least once with NetP enabled
        guard let lastVersionRun = versionStore.lastVersionRun else {
            os_log(.info, log: .networkProtection, "No last version found for the NetP login items, skipping update")
            return
        }

        if lastVersionRun != currentVersion {
            os_log(.info, log: .networkProtection, "App updated from %{public}s to %{public}s: updating login items", lastVersionRun, currentVersion)
            restartNetworkProtectionTunnelAndMenu(using: loginItemsManager)
        } else {
            // If login items failed to launch (e.g. because of the App bundle rename), launch using NSWorkspace
            loginItemsManager.ensureLoginItemsAreRunning(.ifLoginItemsAreEnabled, after: 1)
        }
    }

    private func restartNetworkProtectionTunnelAndMenu(using loginItemsManager: NetworkProtectionLoginItemsManager) {
        loginItemsManager.restartLoginItems()

        Task {
            let provider = NetworkProtectionTunnelController()

            // Restart NetP SysEx on app update
            if await provider.isConnected {
                await provider.stop()
                await provider.start()
            }
        }
    }

    /// Fetches a new list of Network Protection servers, and updates the existing set.
    ///
    private func refreshNetworkProtectionServers() {
        Task {
            let serverCount: Int
            do {
                serverCount = try await NetworkProtectionDeviceManager.create().refreshServerList().count
            } catch {
                os_log("Failed to update Network Protection servers", log: .networkProtection, type: .error)
                return
            }

            os_log("Successfully updated Network Protection servers; total server count = %{public}d", log: .networkProtection, serverCount)
        }
    }
}

#endif
