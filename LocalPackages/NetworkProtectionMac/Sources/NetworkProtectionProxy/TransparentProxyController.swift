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

    private var internalManager: NETransparentProxyManager?

    /// Whether the proxy settings should be stored in the provider configuration.
    ///
    /// We recommend setting this to true if the provider is running in a System Extension and can't access
    /// shared `TransparentProxySettings`.  If the provider is in an App Extension you should instead
    /// use a shared `TransparentProxySettings` and set this to false.
    ///
    private let storeSettingsInProviderConfiguration: Bool
    private let settings: TransparentProxySettings
    private let notificationCenter: NotificationCenter
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
                notificationCenter: NotificationCenter = .default,
                setup: @escaping ManagerSetupCallback) {

        self.extensionID = extensionID
        self.notificationCenter = notificationCenter
        self.settings = settings
        self.setup = setup
        self.storeSettingsInProviderConfiguration = storeSettingsInProviderConfiguration

        subscribeToProviderConfigurationChanges()
        subscribeToSettingsChanges()
    }

    // MARK: - Relay Settings Changes

    private func subscribeToProviderConfigurationChanges() {
        notificationCenter.publisher(for: .NEVPNConfigurationChange)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                self.reloadProviderConfiguration()
            }
            .store(in: &cancellables)
    }

    private func reloadProviderConfiguration() {
        Task { @MainActor in
            try? await self.manager?.loadFromPreferences()
        }
    }

    private func subscribeToSettingsChanges() {
        settings.changePublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: relay(_:))
            .store(in: &cancellables)
    }

    private func relay(_ change: TransparentProxySettings.Change) {
        Task { @MainActor in
            guard let session = await session else {
                return
            }

            switch session.status {
            case .connected, .connecting, .reasserting:
                break
            default:
                return
            }

            try TransparentProxySession(session).send(.changeSetting(change, responseHandler: {
                // no-op
            }))
        }
    }

    // MARK: - Setting up NETransparentProxyManager

    /// Loads the configuration matching our ``extensionID``.
    ///
    public var manager: NETransparentProxyManager? {
        get async {
            if let internalManager {
                return internalManager
            }

            let manager = try? await NETransparentProxyManager.loadAllFromPreferences().first { manager in
                (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == extensionID
            }
            internalManager = manager
            return manager
        }
    }

    /// Loads an existing configuration or creates a new one, if one doesn't exist.
    ///
    /// - Returns a properly configured `NETransparentProxyManager`.
    ///
    public func loadOrCreateConfiguration() async throws -> NETransparentProxyManager {
        let manager = await manager ?? {
            let manager = NETransparentProxyManager()
            internalManager = manager
            return manager
        }()

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

    // MARK: - Connection & Session

    public var connection: NEVPNConnection? {
        get async {
            await manager?.connection
        }
    }

    public var session: NETunnelProviderSession? {
        get async {
            guard let manager = await manager,
                  let session = manager.connection as? NETunnelProviderSession else {

                // The active connection is not running, so there's no session, this is acceptable
                return nil
            }

            return session
        }
    }

    // MARK: - Connection

    public var status: NEVPNStatus {
        get async {
            await connection?.status ?? .disconnected
        }
    }

    // MARK: - Start & stop the proxy

    public var canStart: Bool {
        settings.excludeDBP || settings.excludedApps.count > 0 || settings.excludedDomains.count > 0
    }

    public func start() async throws {
        guard canStart else {
            return
        }

        let manager = try await loadOrCreateConfiguration()
        try manager.connection.startVPNTunnel(options: [:])
    }

    public func stop() async {
        await connection?.stopVPNTunnel()
    }
}
