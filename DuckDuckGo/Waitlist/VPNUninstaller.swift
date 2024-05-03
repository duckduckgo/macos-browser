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
    func uninstall(removeSystemExtension: Bool) async throws
}

final class VPNUninstaller: VPNUninstalling {

    enum UninstallCancellationReason: String {
        case alreadyUninstalling
        case alreadyUninstalled
    }

    enum UninstallError: CustomNSError {
        case cancelled(reason: UninstallCancellationReason)
        case runAgentError(_ error: Error)
        case systemExtensionError(_ error: Error)
        case vpnConfigurationError(_ error: Error)

        var errorCode: Int {
            switch self {
            case .cancelled: return 0
            case .runAgentError: return 1
            case .systemExtensionError: return 2
            case .vpnConfigurationError: return 3
            }
        }

        var errorUserInfo: [String: Any] {
            switch self {
            case .cancelled(let reason):
                return ["reason": reason.rawValue]
            case .runAgentError(let error),
                    .systemExtensionError(let error),
                    .vpnConfigurationError(let error):
                return [NSUnderlyingErrorKey: error as NSError]
            }
        }
    }

    private let log: OSLog
    private let loginItemsManager: LoginItemsManaging
    private let pinningManager: LocalPinningManager
    private let settings: VPNSettings
    private let userDefaults: UserDefaults
    private let vpnMenuLoginItem: LoginItem
    private let ipcClient: TunnelControllerIPCClient

    @MainActor
    private var isDisabling = false

    init(loginItemsManager: LoginItemsManaging = LoginItemsManager(),
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

    /// This method disables the VPN and clear all of its state.
    ///
    /// - Parameters:
    ///     - includeSystemExtension: Whether this method should uninstall the system extension.
    ///
    @MainActor
    func uninstall(removeSystemExtension: Bool) async throws {
        // We can do this optimistically as it has little if any impact.
        unpinNetworkProtection()

        guard !isDisabling else {
            throw UninstallError.cancelled(reason: .alreadyUninstalling)
        }

        guard vpnMenuLoginItem.status.isInstalled else {
            throw UninstallError.cancelled(reason: .alreadyUninstalled)
        }

        isDisabling = true

        defer {
            resetUserDefaults(uninstallSystemExtension: removeSystemExtension)
        }

        do {
            try enableLoginItems()
        } catch {
            throw UninstallError.runAgentError(error)
        }

        // Allow some time for the login items to fully launch
        try? await Task.sleep(interval: 0.5)

        if removeSystemExtension {
            do {
                try await self.removeSystemExtension()
            } catch {
                throw UninstallError.systemExtensionError(error)
            }
        }

        var attemptNumber = 1
        while attemptNumber <= 3 {
            do {
                try await removeVPNConfiguration()
                break // Removal succeeded, break out of the while loop and continue with the rest of uninstallation
            } catch {
                print("Failed to remove VPN configuration, with error: \(error.localizedDescription)")

                if attemptNumber == 3 {
                    throw UninstallError.vpnConfigurationError(error)
                }
            }

            attemptNumber += 1
        }

        // We want to give some time for the login item to reset state before disabling it
        try? await Task.sleep(interval: 0.5)
        disableLoginItems()

        notifyVPNUninstalled()
        isDisabling = false
    }

    private func enableLoginItems() throws {
        try loginItemsManager.throwingEnableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: log)
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
