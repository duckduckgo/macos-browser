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
import LoginItems
import NetworkExtension
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
import PixelKit
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
        case uninstallError(_ error: Error)

        var errorCode: Int {
            switch self {
            case .cancelled: return 0
            case .runAgentError: return 1
            case .systemExtensionError: return 2
            case .vpnConfigurationError: return 3
            case .uninstallError: return 4
            }
        }

        var errorUserInfo: [String: Any] {
            switch self {
            case .cancelled(let reason):
                return ["reason": reason.rawValue]
            case .runAgentError(let error),
                    .systemExtensionError(let error),
                    .vpnConfigurationError(let error),
                    .uninstallError(let error):
                return [NSUnderlyingErrorKey: error as NSError]
            }
        }
    }

    enum IPCUninstallAttempt: PixelKitEventV2 {
        case begin
        case cancelled(_ reason: UninstallCancellationReason)
        case success
        case failure(_ error: Error)

        var name: String {
            switch self {
            case .begin:
                return "vpn_browser_uninstall_attempt_ipc"

            case .cancelled:
                return "vpn_browser_uninstall_cancelled_ipc"

            case .success:
                return "vpn_browser_uninstall_success_ipc"

            case .failure:
                return "vpn_browser_uninstall_failure_ipc"
            }
        }

        var parameters: [String: String]? {
            switch self {
            case .begin,
                    .success,
                    .failure:
                return nil
            case .cancelled(let reason):
                return ["reason": reason.rawValue]
            }
        }

        var error: Error? {
            switch self {
            case .begin,
                    .cancelled,
                    .success:
                return nil
            case .failure(let error):
                return error
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
    private let pixelKit: PixelFiring?

    @MainActor
    private var isDisabling = false

    init(loginItemsManager: LoginItemsManaging = LoginItemsManager(),
         pinningManager: LocalPinningManager = .shared,
         userDefaults: UserDefaults = .netP,
         settings: VPNSettings = .init(defaults: .netP),
         ipcClient: TunnelControllerIPCClient = TunnelControllerIPCClient(),
         vpnMenuLoginItem: LoginItem = .vpnMenu,
         pixelKit: PixelFiring? = PixelKit.shared,
         log: OSLog = .networkProtection) {

        self.log = log
        self.loginItemsManager = loginItemsManager
        self.pinningManager = pinningManager
        self.settings = settings
        self.userDefaults = userDefaults
        self.vpnMenuLoginItem = vpnMenuLoginItem
        self.ipcClient = ipcClient
        self.pixelKit = pixelKit
    }

    /// This method disables the VPN and clear all of its state.
    ///
    /// - Parameters:
    ///     - includeSystemExtension: Whether this method should uninstall the system extension.
    ///
    @MainActor
    func uninstall(removeSystemExtension: Bool) async throws {
        pixelKit?.fire(IPCUninstallAttempt.begin)

        do {
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

            do {
                try await ipcClient.command(.uninstallVPN)
            } catch {
                print("Failed to uninstall VPN, with error: \(error.localizedDescription)")
                throw UninstallError.uninstallError(error)
            }

            // We want to give some time for the login item to reset state before disabling it
            try? await Task.sleep(interval: 0.5)
            disableLoginItems()

            notifyVPNUninstalled()
            isDisabling = false

            pixelKit?.fire(IPCUninstallAttempt.success, frequency: .dailyAndCount)
        } catch UninstallError.cancelled(let reason) {
            pixelKit?.fire(IPCUninstallAttempt.cancelled(reason), frequency: .dailyAndCount)
        } catch {
            pixelKit?.fire(IPCUninstallAttempt.failure(error), frequency: .dailyAndCount)
        }
    }

    private func enableLoginItems() throws {
        try loginItemsManager.throwingEnableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: log)
    }

    func disableLoginItems() {
        loginItemsManager.disableLoginItems(LoginItemsManager.networkProtectionLoginItems)
    }

    func removeSystemExtension() async throws {
#if NETP_SYSTEM_EXTENSION
        do {
            try await ipcClient.command(.removeSystemExtension)
        } catch {
            throw UninstallError.systemExtensionError(error)
        }
#endif
    }

    private func unpinNetworkProtection() {
        pinningManager.unpin(.networkProtection)
    }

    private func removeVPNConfiguration() async throws {
        // Remove the agent VPN configuration
        do {
            try await ipcClient.command(.removeVPNConfiguration)
        } catch {
            throw UninstallError.vpnConfigurationError(error)
        }
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
