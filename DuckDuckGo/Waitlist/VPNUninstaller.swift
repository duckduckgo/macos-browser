//
//  VPNUninstaller.swift
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

import BrowserServicesKit
import Common
import NetworkExtension
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
import LoginItems
import SystemExtensions

protocol VPNUninstalling {
    /// - Returns: `true` if the uninstallation was completed.  `false` if it was cancelled by the user or an error.
    ///
    @discardableResult
    func uninstall(removeSystemExtension: Bool) async -> Bool
}

final class VPNUninstaller: VPNUninstalling {
    private let log: OSLog
    private let loginItemsManager: LoginItemsManager
    private let pinningManager: LocalPinningManager
    private let settings: VPNSettings
    private let userDefaults: UserDefaults
    private let vpnMenuLoginItem: LoginItem
    private let ipcClient: TunnelControllerIPCClient

    @MainActor
    private var isDisabling = false

    init(loginItemsManager: LoginItemsManager = LoginItemsManager(),
         pinningManager: LocalPinningManager = .shared,
         userDefaults: UserDefaults = .netP,
         settings: VPNSettings = .init(defaults: .netP),
         ipcClient: TunnelControllerIPCClient = TunnelControllerIPCClient(),
         vpnMenuLoginItem: LoginItem = .vpnMenu,
         log: OSLog = .networkProtection) {

        self.log = log
        self.loginItemsManager = loginItemsManager
        self.pinningManager = pinningManager
        self.settings = settings
        self.userDefaults = userDefaults
        self.vpnMenuLoginItem = vpnMenuLoginItem
        self.ipcClient = ipcClient
    }

    @MainActor
    private func canUninstall(includingSystemExtension: Bool) -> Bool {
        !isDisabling && vpnMenuLoginItem.status.isInstalled
    }

    /// This method disables the VPN and clear all of its state.
    ///
    /// - Parameters:
    ///     - includeSystemExtension: Whether this method should uninstall the system extension.
    ///
    @MainActor
    @discardableResult
    func uninstall(removeSystemExtension: Bool) async -> Bool {
        // We can do this optimistically as it has little if any impact.
        unpinNetworkProtection()

        // To disable NetP we need the login item to be running
        // This should be fine though as we'll disable them further down below
        guard canUninstall(includingSystemExtension: removeSystemExtension) else {
            return true
        }

        isDisabling = true

        defer {
            resetUserDefaults(uninstallSystemExtension: removeSystemExtension)
        }

        enableLoginItems()

        // Allow some time for the login items to fully launch
        try? await Task.sleep(interval: 0.5)

        if removeSystemExtension {
            do {
                try await self.removeSystemExtension()
            } catch {
                return false
            }
        }

        var attemptNumber = 1
        while attemptNumber <= 3 {
            do {
                try await removeVPNConfiguration()
                break // Removal succeeded, break out of the while loop and continue with the rest of uninstallation
            } catch {
                print("Failed to remove VPN configuration, with error: \(error.localizedDescription)")
            }

            attemptNumber += 1
        }

        // We want to give some time for the login item to reset state before disabling it
        try? await Task.sleep(interval: 0.5)
        disableLoginItems()

        notifyVPNUninstalled()
        isDisabling = false
        return true
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
