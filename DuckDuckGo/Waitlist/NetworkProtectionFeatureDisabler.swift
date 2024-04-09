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
import LoginItems
import SystemExtensions

protocol NetworkProtectionFeatureDisabling {
    /// - Returns: `true` if the uninstallation was completed.  `false` if it was cancelled by the user or an error.
    ///
    @discardableResult
    func disable(keepAuthToken: Bool, uninstallSystemExtension: Bool) async -> Bool

    func stop()
}

final class NetworkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling {
    private let log: OSLog
    private let loginItemsManager: LoginItemsManager
    private let pinningManager: LocalPinningManager
    private let settings: VPNSettings
    private let userDefaults: UserDefaults
    private let ipcClient: TunnelControllerIPCClient

    @MainActor
    private var isDisabling = false

    init(loginItemsManager: LoginItemsManager = LoginItemsManager(),
         pinningManager: LocalPinningManager = .shared,
         userDefaults: UserDefaults = .netP,
         settings: VPNSettings = .init(defaults: .netP),
         ipcClient: TunnelControllerIPCClient = TunnelControllerIPCClient(),
         log: OSLog = .networkProtection) {

        self.log = log
        self.loginItemsManager = loginItemsManager
        self.pinningManager = pinningManager
        self.settings = settings
        self.userDefaults = userDefaults
        self.ipcClient = ipcClient
    }

    @MainActor
    private func canUninstall(includingSystemExtension: Bool) -> Bool {
        !isDisabling && LoginItem.vpnMenu.status.isInstalled
    }

    /// This method disables the VPN and clear all of its state.
    ///
    /// - Parameters:
    ///     - keepAuthToken: If `true`, the auth token will not be removed.
    ///     - includeSystemExtension: Whether this method should uninstall the system extension.
    ///
    @MainActor
    @discardableResult
    func disable(keepAuthToken: Bool, uninstallSystemExtension: Bool) async -> Bool {
        // We can do this optimistically as it has little if any impact.
        unpinNetworkProtection()

        // To disable NetP we need the login item to be running
        // This should be fine though as we'll disable them further down below
        guard canUninstall(includingSystemExtension: uninstallSystemExtension) else {
            return true
        }

        isDisabling = true

        defer {
            resetUserDefaults(uninstallSystemExtension: uninstallSystemExtension)
        }

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

        if !keepAuthToken {
            try? removeAppAuthToken()
        }

        notifyVPNUninstalled()
        isDisabling = false
        return true
    }

    func stop() {
        ipcClient.stop()
    }

    private func enableLoginItems() {
        loginItemsManager.enableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: log)
    }

    func disableLoginItems() {
        loginItemsManager.disableLoginItems(LoginItemsManager.networkProtectionLoginItems)
    }

    func removeSystemExtension() async throws {
#if NETP_SYSTEM_EXTENSION
        try await ipcClient.debugCommand(.removeSystemExtension)
#endif
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
    }

    private func resetUserDefaults(uninstallSystemExtension: Bool) {
        settings.resetToDefaults()

        if uninstallSystemExtension {
            userDefaults.networkProtectionOnboardingStatus = .default
        } else {
            userDefaults.networkProtectionOnboardingStatus = .isOnboarding(step: .userNeedsToAllowVPNConfiguration)
        }
    }

    private func notifyVPNUninstalled() {
            // Wait a bit since the NetP button is likely being hidden
        Task {
            try? await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
            userDefaults.networkProtectionShouldShowVPNUninstalledMessage = true
        }
    }
}

#endif
