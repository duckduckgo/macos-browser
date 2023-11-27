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

#if NETWORK_PROTECTION
import Common
import Foundation
import LoginItems
import NetworkProtection
import NetworkProtectionUI
import NetworkProtectionIPC
import NetworkExtension

/// Implements the sequence of steps that Network Protection needs to execute when the App starts up.
///
final class NetworkProtectionAppEvents {

    // MARK: - Legacy VPN Item and Extension

#if NETP_SYSTEM_EXTENSION
#if DEBUG
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent.debug"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.debug.network-protection-extension"
#elseif REVIEW
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent.review"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.review.network-protection-extension"
#else
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.network-protection-extension"
#endif // DEBUG || REVIEW || RELEASE
#endif // NETP_SYSTEM_EXTENSION

    // MARK: - Feature Visibility

    private let featureVisibility: NetworkProtectionFeatureVisibility

    init(featureVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility()) {
        self.featureVisibility = featureVisibility
    }

    /// Call this method when the app finishes launching, to run the startup logic for NetP.
    ///
    func applicationDidFinishLaunching() {
        let loginItemsManager = LoginItemsManager()

        Task {
            await removeLegacyLoginItemAndVPNConfiguration()
            migrateNetworkProtectionAuthTokenToSharedKeychainIfNecessary()

            guard featureVisibility.isNetworkProtectionVisible() else {
                featureVisibility.disableForAllUsers()
                return
            }

            restartNetworkProtectionIfVersionChanged(using: loginItemsManager)
            refreshNetworkProtectionServers()
        }
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
        }
    }

    private func restartNetworkProtectionTunnelAndMenu(using loginItemsManager: LoginItemsManager) {

        loginItemsManager.restartLoginItems(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection)

        Task {
            let machServiceName = Bundle.main.vpnMenuAgentBundleId
            let ipcClient = TunnelControllerIPCClient(machServiceName: machServiceName)
            let controller = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)

            // Restart NetP SysEx on app update
            if controller.isConnected {
                await controller.stop()
                await controller.start()
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

    // MARK: - Legacy Login Item and Extension

    private func removeLegacyLoginItemAndVPNConfiguration() async {
        LoginItem(bundleId: legacyAgentBundleID).forceStop()

        let tunnels = try? await NETunnelProviderManager.loadAllFromPreferences()
        let tunnel = tunnels?.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == legacySystemExtensionBundleID
        }

        guard let tunnel else {
            return
        }

        UserDefaults.netP.networkProtectionOnboardingStatusRawValue = OnboardingStatus.default.rawValue

        try? await tunnel.removeFromPreferences()
    }
}

#endif
