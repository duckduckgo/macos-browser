//
//  NetworkProtectionFeatureDisabler.swift
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

import BrowserServicesKit
import Common
import NetworkExtension
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
import SystemExtensions

protocol NetworkProtectionFeatureDisabling {
    /// - Returns: `true` if the uninstallation was completed.  `false` if it was cancelled by the user or an error.
    ///
    func disable(keepAuthToken: Bool, uninstallSystemExtension: Bool) async -> Bool
}

final class NetworkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling {
    static let vpnUninstalledNotificationName = NSNotification.Name(rawValue: "com.duckduckgo.NetworkProtection.uninstalled")

    private let log: OSLog
    private let loginItemsManager: LoginItemsManager
    private let pinningManager: LocalPinningManager
    private let settings: VPNSettings
    private let userDefaults: UserDefaults
    private let ipcClient: TunnelControllerIPCClient

    init(loginItemsManager: LoginItemsManager = LoginItemsManager(),
         pinningManager: LocalPinningManager = .shared,
         userDefaults: UserDefaults = .shared,
         settings: VPNSettings = .init(defaults: .shared),
         ipcClient: TunnelControllerIPCClient = TunnelControllerIPCClient(machServiceName: Bundle.main.vpnMenuAgentBundleId),
         log: OSLog = .networkProtection) {

        self.log = log
        self.loginItemsManager = loginItemsManager
        self.pinningManager = pinningManager
        self.settings = settings
        self.userDefaults = userDefaults
        self.ipcClient = ipcClient
    }

    /// This method disables Network Protection and clear all of its state.
    ///
    /// - Parameters:
    ///     - keepAuthToken: If `true`, the auth token will not be removed.
    ///     - includeSystemExtension: Whether this method should uninstall the system extension.
    ///
    @discardableResult
    func disable(keepAuthToken: Bool, uninstallSystemExtension: Bool) async -> Bool {
        // To disable NetP we need the login item to be running
        // This should be fine though as we'll disable them further down below
        enableLoginItems()

        // Allow some time for the login items to fully launch
        try? await Task.sleep(interval: 0.5)

        if uninstallSystemExtension {
            do {
                try await removeSystemExtension()
            } catch {
                return false
            }
        }

        try? await removeVPNConfiguration()
        // We want to give some time for the login item to reset state before disabling it
        try? await Task.sleep(interval: 0.5)
        disableLoginItems()
        resetUserDefaults()

        if !keepAuthToken {
            try? removeAppAuthToken()
        }

        unpinNetworkProtection()
        postVPNUninstalledNotification()
        return true
    }

    private func enableLoginItems() {
        loginItemsManager.enableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: log)
    }

    func disableLoginItems() {
        loginItemsManager.disableLoginItems(LoginItemsManager.networkProtectionLoginItems)
    }

    func removeSystemExtension() async throws {
        try await ipcClient.debugCommand(.removeSystemExtension)
    }

    private func unpinNetworkProtection() {
        pinningManager.unpin(.networkProtection)
    }

    private func removeAppAuthToken() throws {
        try NetworkProtectionKeychainTokenStore().deleteToken()
    }

    private func removeVPNConfiguration() async throws {
        // Remove the agent VPN configuration
        try await ipcClient.debugCommand(.removeVPNConfiguration)

        // Remove the legacy (local) configuration
        // We don't care if this fails
        let tunnels = try? await NETunnelProviderManager.loadAllFromPreferences()

        if let tunnels = tunnels {
            for tunnel in tunnels {
                tunnel.connection.stopVPNTunnel()
                try? await tunnel.removeFromPreferences()
            }
        }
    }

    private func resetUserDefaults() {
        settings.resetToDefaults()
    }

    private func postVPNUninstalledNotification() {
        Task { @MainActor in
            // Wait a bit since the NetP button is likely being hidden
            try? await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)

            NotificationCenter.default.post(
                name: Self.vpnUninstalledNotificationName,
                object: nil)
        }
    }
}

#endif
