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

import Combine
import Foundation
import NetworkExtension
import NetworkProtection
import OSLog // swiftlint:disable:this enforce_os_log_wrapper
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

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializers

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

        subscribeToSettingsChanges()
    }

    // MARK: - Relay Settings Changes

    private func subscribeToSettingsChanges() {
        settings.changePublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: relay(_:))
            .store(in: &cancellables)
    }

    private func relay(_ change: TransparentProxySettings.Change) {
        Task { @MainActor in
            guard await isConnected, let activeSession = await activeSession() else {
                return
            }

            do {
                try TransparentProxySession(activeSession).send(.changeSetting(change, responseHandler: {
                    // no-op
                }))
            } catch {
                // throw error?
                os_log("🤌 Setting change relay: Some error! %{public}@", String(describing: error))
            }
        }
    }

    // MARK: - Setting up NETransparentProxyManager

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

        guard let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            assertionFailure("Could not retrieve providerProtocol. The proxy will fail to start up")
            return
        }

        var providerConfiguration = providerProtocol.providerConfiguration ?? [String: Any]()

        guard let encodedSettings = try? JSONEncoder().encode(settings.snapshot()),
              let encodedSettingsString = String(data: encodedSettings, encoding: .utf8) else {

            assertionFailure("Could not encode settings. The proxy will fail to start up")
            return
        }

        providerConfiguration[TransparentProxySettingsSnapshot.key] = encodedSettingsString as NSString
        providerProtocol.providerConfiguration = providerConfiguration

    }

    // MARK: - Session

    public func activeSession() async -> NETunnelProviderSession? {
        guard let manager = await loadExisting(),
              let session = manager.connection as? NETunnelProviderSession else {

            // The active connection is not running, so there's no session, this is acceptable
            return nil
        }

        return session
    }

    // MARK: - Connection

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
    }

    public func stop() async {
        guard let manager = await loadExisting() else {
            return
        }

        manager.connection.stopVPNTunnel()
    }
}
