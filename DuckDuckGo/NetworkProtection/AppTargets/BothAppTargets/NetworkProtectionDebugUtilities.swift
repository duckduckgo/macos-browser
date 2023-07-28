//
//  NetworkProtectionDebugUtilities.swift
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
import NetworkExtension
import NetworkProtection
import SystemExtensions

#if NETWORK_PROTECTION

/// Utility code to help implement our debug menu options for Network Protection.
///
final class NetworkProtectionDebugUtilities {

    // MARK: - Registration Key Validity

    @UserDefaultsWrapper(key: .networkProtectionRegistrationKeyValidity, defaultValue: nil)
    var registrationKeyValidity: TimeInterval? {
        didSet {
            Task {
                await sendRegistrationKeyValidityToProvider()
            }
        }
    }

    // MARK: - Login Items Management

    private let loginItemsManager: NetworkProtectionLoginItemsManager

    // MARK: - Server Selection

    private let selectedServerStore = NetworkProtectionSelectedServerUserDefaultsStore()

    // MARK: - Initializers

    init(loginItemsManager: NetworkProtectionLoginItemsManager = .init()) {
        self.loginItemsManager = loginItemsManager
    }

    // MARK: - Debug commands for the extension

    func resetAllState() async throws {
        if let activeSession = try? await ConnectionSessionUtilities.activeSession() {
            try? activeSession.sendProviderMessage(.resetAllState) {
                os_log("Status was reset in the extension", log: .networkProtection)
            }
        }

        // ☝️ Take care of resetting all state within the extension first, and wait half a second
        try? await Task.sleep(interval: 0.5)
        // 👇 And only afterwards turn off the tunnel and remove it from preferences

        let tunnels = try? await NETunnelProviderManager.loadAllFromPreferences()

        if let tunnels = tunnels {
            for tunnel in tunnels {
                tunnel.connection.stopVPNTunnel()
                try? await tunnel.removeFromPreferences()
            }
        }

        NetworkProtectionSelectedServerUserDefaultsStore().reset()

        try await removeSystemExtensionAndAgents()
    }

    func removeSystemExtensionAndAgents() async throws {
        try await loginItemsManager.resetLoginItems()

#if NETP_SYSTEM_EXTENSION
        do {
            try await SystemExtensionManager().deactivate()
        } catch OSSystemExtensionError.extensionNotFound {
            // This is an intentional no-op to silence this type of error
        } catch {
            throw error
        }
#endif
    }

    func sendTestNotificationRequest() async throws {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        try? activeSession.sendProviderMessage(.triggerTestNotification)
    }

    // MARK: - Registation Key

    private func sendRegistrationKeyValidityToProvider() async {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        try? activeSession.sendProviderMessage(.setKeyValidity(registrationKeyValidity))
    }

    func expireRegistrationKeyNow() async {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        try? activeSession.sendProviderMessage(.expireRegistrationKey)
    }

    // MARK: - Server Selection

    func selectedServerName() -> String? {
        selectedServerStore.selectedServer.stringValue
    }

    func setSelectedServer(selectedServer: SelectedNetworkProtectionServer) {
        selectedServerStore.selectedServer = selectedServer

        Task {
            guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
                return
            }

            try? activeSession.sendProviderMessage(.setSelectedServer(selectedServer.stringValue))
        }
    }
}

#endif
