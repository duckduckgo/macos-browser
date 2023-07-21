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

/// Utility code to help implement our debug menu options for Network Protection.
///
final class NetworkProtectionDebugUtilities {

    // MARK: - Registration Key Validity

    static let registrationKeyValidityKey = "com.duckduckgo.network-protection.NetworkProtectionTunnelController.registrationKeyValidityKey"

    // MARK: - Login Items Management

    private let loginItemsManager:NetworkProtectionLoginItemsManager

    // MARK: - Server Selection

    private let selectedServerStore = NetworkProtectionSelectedServerUserDefaultsStore()

    // MARK: - Initializers

    init(loginItemsManager: NetworkProtectionLoginItemsManager = .init()) {
        self.loginItemsManager = loginItemsManager
    }

    // MARK: - Debug commands for the extension

    func resetAllState() async throws {
        if let activeSession = try? await ConnectionSessionUtilities.activeSession() {
            try? activeSession.sendProviderMessage(Data([ExtensionMessage.resetAllState.rawValue])) { _ in
                os_log("Status was reset in the extension", log: .networkProtection)
            }
        }

        // ☝️ Take care of resetting all state within the extension first, and wait half a second
        try? await Task.sleep(interval: 0.5)
        // 👇 And only afterwards turn off the tunnel and remove it from prefernces

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
        try await requestUserAuthorizationAndDo {
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
    }

    func sendTestNotificationRequest() async throws {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        let request = Data([ExtensionMessage.triggerTestNotification.rawValue])
        try? activeSession.sendProviderMessage(request)
    }

    // MARK: - Registration Key

    /// Retrieves the registration key validity time interval.
    ///
    /// - Returns: the validity time interval if it was overridden, or `nil` if NetP is using defaults.
    ///
    func registrationKeyValidity(defaults: UserDefaults = .standard) -> TimeInterval? {
        defaults.object(forKey: Self.registrationKeyValidityKey) as? TimeInterval
    }

    /// Sets the registration key validity time interval.
    ///
    /// - Parameters:
    ///     - validity: the default registration key validity time interval.  A `nil` value means it will be automatically
    ///         defined by NetP using its standard configuration.
    ///
    func setRegistrationKeyValidity(_ validity: TimeInterval?, defaults: UserDefaults = .standard) async throws {
        guard let activeSession = try await ConnectionSessionUtilities.activeSession() else {
            return
        }

        var request = Data([ExtensionMessage.setKeyValidity.rawValue])

        if let validity = validity {
            defaults.set(validity, forKey: Self.registrationKeyValidityKey)

            let validityData = withUnsafeBytes(of: UInt(validity).littleEndian) { Data($0) }
            request.append(validityData)
        } else {
            defaults.removeObject(forKey: Self.registrationKeyValidityKey)
        }

        try activeSession.sendProviderMessage(request)
    }

    func expireRegistrationKeyNow() async throws {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        let request = Data([ExtensionMessage.expireRegistrationKey.rawValue])
        try? activeSession.sendProviderMessage(request)
    }

    // MARK: - Server Selection

    func selectedServerName() -> String? {
        selectedServerStore.selectedServer.stringValue
    }

    func setSelectedServer(selectedServer: SelectedNetworkProtectionServer) {
        selectedServerStore.selectedServer = selectedServer

        let selectedServerName: String?

        if case .endpoint(let serverName) = selectedServer {
            selectedServerName = serverName
        } else {
            selectedServerName = nil
        }

        Task {
            guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
                return
            }

            var request = Data([ExtensionMessage.setSelectedServer.rawValue])

            if let selectedServerName = selectedServerName {
                let serverNameData = selectedServerName.data(using: ExtensionMessage.preferredStringEncoding)!
                request.append(serverNameData)
            }

            try? activeSession.sendProviderMessage(request)
        }
    }

    // MARK: - Elevated Privileges

#if !APPSTORE
    /// This method allows to request user authorization to perform privileged code.
    ///
    func requestUserAuthorizationAndDo(_ callback: () async throws -> Void) async throws {

        var authorizationRef: AuthorizationRef?
        let prompt = "Please enter your administrator password to run the command"

        // Prompt the user for admin privileges
        let status = AuthorizationCreate(nil, nil, [.extendRights, .interactionAllowed], &authorizationRef)

        guard status == errAuthorizationSuccess,
              let authorizationRef else {

            print("Failed to create authorization: \(status)")
            return
        }

        // Create an AuthorizationItem to define the right and environment
        let authItem = AuthorizationItem(name: kAuthorizationRightExecute, valueLength: 0, value: nil, flags: 0)
        var authItems = [authItem]
        var authRights = AuthorizationRights(count: UInt32(authItems.count), items: &authItems)
        let authFlags: AuthorizationFlags = [.extendRights, .interactionAllowed]

        // Prompt the user for the admin password
        let authStatus = AuthorizationCopyRights(authorizationRef, &authRights, nil, authFlags, nil)

        guard authStatus == errAuthorizationSuccess else {
            print("Authorization failed: \(authStatus)")
            AuthorizationFree(authorizationRef, authFlags)
            return
        }

        try await callback()

        // Clean up and free the AuthorizationRef
        AuthorizationFree(authorizationRef, authFlags)
    }
#endif
}
