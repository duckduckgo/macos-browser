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
import PixelKit
import SystemExtensions

/// Controller for ``TransparentProxyProvider``
///
@MainActor
public final class TransparentProxyController {

    public enum StartError: Error {
        case attemptToStartWithoutBackingActiveFeatures
        case couldNotRetrieveProtocolConfiguration
        case couldNotEncodeSettingsSnapshot
        case failedToLoadConfiguration(_ error: Error)
        case failedToSaveConfiguration(_ error: Error)
        case failedToStartProvider(_ error: Error)
    }

    public typealias EventCallback = (Event) -> Void
    public typealias ManagerSetupCallback = (_ manager: NETransparentProxyManager) async -> Void

    /// Dry mode means this won't really do anything to start or stop the proxy.
    ///
    /// This is useful for testing.
    ///
    private let dryMode: Bool

    /// The bundleID of the extension that contains the ``TransparentProxyProvider``.
    ///
    private let extensionID: String

    /// The event handler
    ///
    public var eventHandler: EventCallback?

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
    public let settings: TransparentProxySettings
    private let notificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializers

    /// Default initializer.
    ///
    /// - Parameters:
    ///     - extensionID: the bundleID for the extension that contains the ``TransparentProxyProvider``.
    ///         This class DOES NOT take any responsibility in installing the system extension.  It only uses
    ///         the extensionID to identify the appropriate manager configuration to load / save.
    ///     - storeSettingsInProviderConfiguration: whether the provider configuration will be used for storing
    ///         the proxy settings.  Should be `true` when using a System Extension and `false` when using
    ///         an App Extension.
    ///     - settings: the settings to use for this proxy.
    ///     - dryMode: whether this class is initialized in dry mode.
    ///     - setup: a callback that will be called whenever a ``NETransparentProxyManager`` needs
    ///         to be setup.
    ///
    public init(extensionID: String,
                storeSettingsInProviderConfiguration: Bool,
                settings: TransparentProxySettings,
                notificationCenter: NotificationCenter = .default,
                dryMode: Bool = false,
                setup: @escaping ManagerSetupCallback) {

        self.dryMode = dryMode
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
            .sink { _ in
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

    /// Loads a saved manager
    ///
    /// This is a bit of a hack that will be run just once for the instance.  The reason we want this to run only once is that
    /// `NETransparentProxyManager.loadAllFromPreferences()` has a bug where it triggers status change
    /// notifications.  If the code trying to retrieve the manager is the result of a notification, we may soon find outselves
    /// in an infinite loop.
    ///
    private var triedLoadingManager = false

    /// Loads the configuration matching our ``extensionID``.
    ///
    public var manager: NETransparentProxyManager? {
        get async {
            if let internalManager {
                return internalManager
            }

            if !triedLoadingManager {
                triedLoadingManager = true

                let manager = try? await NETransparentProxyManager.loadAllFromPreferences().first { manager in
                    (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == extensionID
                }
                self.internalManager = manager
            }

            return internalManager
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
        try setupAdditionalProviderConfiguration(manager)

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        return manager
    }

    private func setupAdditionalProviderConfiguration(_ manager: NETransparentProxyManager) throws {
        guard storeSettingsInProviderConfiguration else {
            return
        }

        guard let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            throw StartError.couldNotRetrieveProtocolConfiguration
        }

        var providerConfiguration = providerProtocol.providerConfiguration ?? [String: Any]()

        guard let encodedSettings = try? JSONEncoder().encode(settings.snapshot()),
              let encodedSettingsString = String(data: encodedSettings, encoding: .utf8) else {

            throw StartError.couldNotEncodeSettingsSnapshot
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

    public var isRequiredForActiveFeatures: Bool {
        settings.appRoutingRules.count > 0 || settings.excludedDomains.count > 0
    }

    public func start() async throws {
        eventHandler?(.startInitiated)

        guard isRequiredForActiveFeatures else {
            let error = StartError.attemptToStartWithoutBackingActiveFeatures
            eventHandler?(.startFailure(error))
            throw error
        }

        let manager: NETransparentProxyManager

        do {
            manager = try await loadOrCreateConfiguration()
        } catch {
            eventHandler?(.startFailure(error))
            throw error
        }

        do {
            try manager.connection.startVPNTunnel(options: [:])
        } catch {
            let error = StartError.failedToStartProvider(error)
            eventHandler?(.startFailure(error))
            throw error
        }

        eventHandler?(.startSuccess)
    }

    public func stop() async {
        await connection?.stopVPNTunnel()
    }
}
