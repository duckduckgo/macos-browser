//
//  TransparentProxyController.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Foundation
import NetworkExtension
import SystemExtensions

/// Controller for ``TransparentProxyProvider``
///
@MainActor
public final class TransparentProxyController {

    public typealias ManagerSetupCallback = (_ manager: NETransparentProxyManager) async -> Void

    /// The bundleID of the extension that contains the ``TransparentProxyProvider``.
    ///
    private let extensionID: String

    /// Callback to set up a ``NETransparentProxyManager``.
    ///
    public let setup: ManagerSetupCallback

    /// Whether the proxy settings should be stored in the provider configuration.
    ///
    /// We recommend setting this to true if the provider is running in a System Extension and can't access
    /// shared `TransparentProxySettings`.  If the provider is in an App Extension you should instead
    /// use a shared `TransparentProxySettings` and set this to false.
    ///
    private let storeSettingsInProviderConfiguration: Bool

    private let settings: TransparentProxySettings

    /// Default initializer.
    ///
    /// - Parameters:
    ///     - extensionID: the bundleID for the extension that contains the ``TransparentProxyProvider``.
    ///         This class DOES NOT take any responsibility in installing the system extension.  It only uses
    ///         the extensionID to identify the appropriate manager configuration to load / save.
    ///     - settings: the settings to use for this proxy.
    ///     - setup: a callback that will be called whenever a ``NETransparentProxyManager`` needs
    ///         to be setup.
    ///
    public init(extensionID: String,
                storeSettingsInProviderConfiguration: Bool,
                settings: TransparentProxySettings,
                setup: @escaping ManagerSetupCallback) {

        self.extensionID = extensionID
        self.settings = settings
        self.setup = setup
        self.storeSettingsInProviderConfiguration = storeSettingsInProviderConfiguration
    }

    /// Loads the configuration matching our ``extensionID``.
    ///
    public func loadExisting() async -> NETransparentProxyManager? {
        try? await NETransparentProxyManager.loadAllFromPreferences().first { manager in
            (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == extensionID
        }
    }

    /// Loads an existing configuration or creates a new one, if one doesn't exist.
    ///
    /// - Returns a properly configured `NETransparentProxyManager`.
    ///
    public func loadOrCreateConfiguration() async throws -> NETransparentProxyManager {
        let manager = await loadExisting() ?? NETransparentProxyManager()

        await setup(manager)
        setupAdditionalProviderConfiguration(manager)

        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
        } catch {
            print(error.localizedDescription)
        }

        return manager
    }

    private func setupAdditionalProviderConfiguration(_ manager: NETransparentProxyManager) {
        guard storeSettingsInProviderConfiguration else {
            return
        }

        guard var providerConfiguration = (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
              let encodedSettings = try? JSONEncoder().encode(settings.snapshot()) else {

            assertionFailure("Could not set provider configuration, proxy will fail to start up")
            //os_log("Could not set provider configuration, proxy will fail to start up")
            return
        }

        providerConfiguration[TransparentProxySettingsSnapshot.key] = encodedSettings as NSData
    }

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    public var isConnected: Bool {
        get async {
            guard let manager = await loadExisting() else {
                return false
            }

            switch manager.connection.status {
            case .connected, .connecting, .reasserting:
                return true
            default:
                return false
            }
        }
    }

    public func start() async throws {
        let manager = try await loadOrCreateConfiguration()
        try manager.connection.startVPNTunnel(options: [:])

        do {
            try await enableOnDemand(tunnelManager: manager)
        } catch {
            // fire pixel
            // log error
            // don't re-throw because this shouldn't interrupt the connection
        }
    }

    public func stop() async {
        guard let manager = await loadExisting() else {
            return
        }

        do {
            try await disableOnDemand(tunnelManager: manager)
        } catch {
            // fire pixel
            // log error
            // don't re-throw because this shouldn't interrupt the connection
        }

        manager.connection.stopVPNTunnel()
    }

    // MARK: - On Demand & Kill Switch

    @MainActor
    func enableOnDemand(tunnelManager: NETransparentProxyManager) async throws {
        /*
        let rule = NEOnDemandRuleConnect()
        rule.interfaceTypeMatch = .any

        tunnelManager.onDemandRules = [rule]
        tunnelManager.isOnDemandEnabled = true

        try await tunnelManager.saveToPreferences()
         */
    }

    @MainActor
    func disableOnDemand(tunnelManager: NETransparentProxyManager) async throws {
        /*
        tunnelManager.isOnDemandEnabled = false

        try await tunnelManager.saveToPreferences()
         */
    }
}
