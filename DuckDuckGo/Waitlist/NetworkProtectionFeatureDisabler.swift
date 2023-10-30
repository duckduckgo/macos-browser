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
    func disable(keepAuthToken: Bool, uninstallSystemExtension: Bool)
}

final class NetworkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling {
    private let log: OSLog
    private let loginItemsManager: LoginItemsManager
    private let pinningManager: LocalPinningManager
    private let settings: TunnelSettings
    private let userDefaults: UserDefaults
    private let ipcClient: TunnelControllerIPCClient

    init(loginItemsManager: LoginItemsManager = LoginItemsManager(),
         pinningManager: LocalPinningManager = .shared,
         userDefaults: UserDefaults = .shared,
         settings: TunnelSettings = .init(defaults: .shared),
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
    func disable(keepAuthToken: Bool, uninstallSystemExtension: Bool) {
        Task {
            unpinNetworkProtection()

            if uninstallSystemExtension {
                await resetAllStateForVPNApp(uninstallSystemExtension: uninstallSystemExtension)
            }

            disableLoginItems()

            await resetNetworkExtensionState()

            // ☝️ Take care of resetting all state within the extension first, and wait half a second
            try? await Task.sleep(interval: 0.5)
            // 👇 And only afterwards turn off the tunnel and remove it from preferences

            await stopTunnel()
            resetUserDefaults()

            if !keepAuthToken {
                try? removeAppAuthToken()
            }
        }
    }

    func disableLoginItems() {
        loginItemsManager.disableLoginItems(LoginItemsManager.networkProtectionLoginItems)
    }

    func resetAllStateForVPNApp(uninstallSystemExtension: Bool) async {
        await ipcClient.resetAll(uninstallSystemExtension: uninstallSystemExtension)

#if NETP_SYSTEM_EXTENSION
        userDefaults.networkProtectionOnboardingStatusRawValue = OnboardingStatus.default.rawValue
#endif
    }

    private func unpinNetworkProtection() {
        pinningManager.unpin(.networkProtection)
    }

    private func removeAppAuthToken() throws {
        try NetworkProtectionKeychainTokenStore().deleteToken()
    }

    private func resetNetworkExtensionState() async {
        if let activeSession = try? await ConnectionSessionUtilities.activeSession() {
            try? activeSession.sendProviderMessage(.resetAllState) {
                os_log("Status was reset in the extension", log: self.log)
            }
        }
    }

    private func stopTunnel() async {
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
        userDefaults.networkProtectionOnboardingStatusRawValue = OnboardingStatus.default.rawValue
    }
}

#endif
