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
final class NetworkProtectionAppEvents {

    private let featureVisibility: NetworkProtectionFeatureVisibility

    init(featureVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility()) {
        self.featureVisibility = featureVisibility
    }

    /// Call this method when the app finishes launching, to run the startup logic for NetP.
    ///
    func applicationDidFinishLaunching() {
        migrateNetworkProtectionAuthTokenToSharedKeychainIfNecessary()

        let loginItemsManager = LoginItemsManager()
        let keychainStore = NetworkProtectionKeychainTokenStore()

        guard featureVisibility.isNetworkProtectionVisible() else {
            featureVisibility.disableForAllUsers()
            return
        }

        restartNetworkProtectionIfVersionChanged(using: loginItemsManager)
        refreshNetworkProtectionServers()
    }

    /// Call this method when the app becomes active to run the associated NetP logic.
    ///
    func applicationDidBecomeActive() {
        guard featureVisibility.isNetworkProtectionVisible() else {
            featureVisibility.disableForAllUsers()
            return
        }
    }

    /// If necessary, this method migrates the auth token from an unspecified data protection keychain (our previous
    /// storage location), to the new shared keychain, which is where apps in our app group will try to access the NetP
    /// auth token.
    ///
    /// This method bails out on any error condition - the user will probably have to re-enter their auth token if we can't
    /// migrate this, and that's ok.  This migration only affects internal users so it's not worth pixeling, and it's not worth
    /// alerting the user to an error since they'll see Network Protection disable and eventually re-enable it.
    ///
    private func migrateNetworkProtectionAuthTokenToSharedKeychainIfNecessary() {
        let sharedKeychainStore = NetworkProtectionKeychainTokenStore()

        guard !sharedKeychainStore.isFeatureActivated else {
            // We only migrate if the auth token is missing from our new shared keychain.
            return
        }

        let legacyServiceName = "\(Bundle.main.bundleIdentifier!).authToken"
        let legacyKeychainStore = NetworkProtectionKeychainTokenStore(keychainType: .dataProtection(.unspecified),
                                                                      serviceName: legacyServiceName,
                                                                      errorEvents: nil)

        guard let token = try? legacyKeychainStore.fetchToken() else {
            // If fetching the token fails, we just assume we can't migrate anything and the user
            // will need to re-enable NetP.
            return
        }

        do {
            try sharedKeychainStore.store(token)
        } catch {
            print(String(describing: error))
        }
    }

    private func restartNetworkProtectionIfVersionChanged(using loginItemsManager: LoginItemsManager) {
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
            loginItemsManager.ensureLoginItemsAreRunning(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection, condition: .ifLoginItemsAreEnabled, after: 1)
        }
    }

    private func restartNetworkProtectionTunnelAndMenu(using loginItemsManager: LoginItemsManager) {
        loginItemsManager.restartLoginItems(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection)

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
