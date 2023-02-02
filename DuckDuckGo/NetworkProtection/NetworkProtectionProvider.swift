//
//  NSImage+NetworkProtection.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Combine
import SwiftUI
import OSLog
import BrowserServicesKit
import NetworkExtension
import NetworkProtection
import SystemExtensions
import Common

enum NetworkProtectionConnectionStatus {
    case notConfigured
    case disconnected
    case disconnecting(connectedDate: Date, serverAddress: String, serverLocation: String)
    case connected(connectedDate: Date, serverAddress: String, serverLocation: String)
    case connecting
    case unknown
}

typealias NetworkProtectionStatusChangeHandler = (NetworkProtectionConnectionStatus) -> Void
typealias NetworkProtectionConfigChangeHandler = () -> Void

protocol NetworkProtectionProvider {

    // MARK: - Polling Connection State

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    func isConnected() async -> Bool

    // MARK: - Starting & Stopping the VPN

    /// Starts the VPN connection used for Network Protection
    ///
    func start() async throws

    /// Stops the VPN connection used for Network Protection
    ///
    func stop() async throws

    // MARK: - Config & Status Change Publishers

    var configChangePublisher: CurrentValueSubject<Void, Never> { get }
    var statusChangePublisher: CurrentValueSubject<NetworkProtectionConnectionStatus, Never> { get }
}

final class DefaultNetworkProtectionProvider: NetworkProtectionProvider {

    // MARK: - Errors & Logging

    enum QuickConfigLoadingError: Error {
        case quickConfigFilePathEnvVarMissing
    }

    /// The logger that this object will use for errors that are handled by this class.
    ///
    private let logger: NetworkProtectionLogger

    /// Handles registration of the current device with the Network Protection backend.
    /// The manager is also responsible to maintaining the current known list of backend servers, and allowing the user to pick which one they connect to.
    /// 
    private let deviceManager: NetworkProtectionDeviceManagement

    private let selectedServerStore: NetworkProtectionSelectedServerStore

    // MARK: - Notifications & Observers

    /// The notification center to use to observe tunnel change notifications.
    ///
    private let notificationCenter: NotificationCenter

    /// The observer token for VPN status changes,
    ///
    private var statusChangeObserverToken: NSObjectProtocol?

    /// The observer token for VPN configuration changes,
    ///
    private var configChangeObserverToken: NSObjectProtocol?

    let configChangePublisher = CurrentValueSubject<Void, Never>(())
    let statusChangePublisher = CurrentValueSubject<NetworkProtectionConnectionStatus, Never>(.unknown)

    // MARK: - VPN Tunnel & Configuration

    /// The environment variable that holds the path to the WG quick configuration file that will be used for the tunnel.
    ///
    static let quickConfigFilePathEnvironmentVariable = "NETP_QUICK_CONFIG_FILE_PATH"

    /// The path of the WG quick configuration file that is used when the environment variable is not present.
    static let defaultConfigFilePath = "~/NetworkProtection.conf"

    /// The actual storage for our tunnel manager.
    ///
    private var internalTunnelManager: NETunnelProviderManager?

    /// The tunnel manager: will try to load if it its not loaded yet, but if one can't be loaded from preferences,
    /// a new one will not be created.  This is useful for querying the connection state and information without triggering
    /// a VPN-access popup to the user.
    ///
    private var tunnelManager: NETunnelProviderManager? {
        get async {
            guard let tunnelManager = internalTunnelManager else {
                let tunnelManager = await loadTunnelManager()
                internalTunnelManager = tunnelManager
                return tunnelManager
            }

            return tunnelManager
        }
    }

    private func loadTunnelManager() async -> NETunnelProviderManager? {
        try? await NETunnelProviderManager.loadAllFromPreferences().first
    }

    private func loadOrMakeTunnelManager() async throws -> NETunnelProviderManager {
        guard let tunnelManager = await tunnelManager else {
            let tunnelManager = NETunnelProviderManager()
            try await setupAndSave(tunnelManager)
            internalTunnelManager = tunnelManager
            return tunnelManager
        }

        try await setupAndSave(tunnelManager)
        return tunnelManager
    }

    private func setupAndSave(_ tunnelManager: NETunnelProviderManager) async throws {
        try await setup(tunnelManager)
        try await tunnelManager.saveToPreferences()
        try await tunnelManager.loadFromPreferences()
    }

    // MARK: - Initialization & Deinitialization

    convenience init(subscribeToDebugNotifications: Bool = false) {
        self.init(notificationCenter: .default,
                  subscribeToDebugNotifications: subscribeToDebugNotifications,
                  deviceManager: NetworkProtectionDeviceManager(errorEvents: Self.networkProtectionDebugEvents),
                  selectedServerStore: NetworkProtectionSelectedServerUserDefaultsStore(),
                  logger: DefaultNetworkProtectionLogger())
    }

    /// Default initializer
    ///
    /// - Parameters:
    ///         - notificationCenter: (meant for testing) the notification center that this object will use.
    ///         - logger: (meant for testing) the logger that this object will use.
    ///
    init(notificationCenter: NotificationCenter,
         subscribeToDebugNotifications: Bool,
         deviceManager: NetworkProtectionDeviceManagement,
         selectedServerStore: NetworkProtectionSelectedServerStore,
         logger: NetworkProtectionLogger) {

        self.logger = logger
        self.deviceManager = deviceManager
        self.selectedServerStore = selectedServerStore
        self.notificationCenter = notificationCenter

        startObservingNotifications(subscribeToDebugNotifications: subscribeToDebugNotifications)

        Task {
            // Make sure the tunnel is loaded
            _ = await tunnelManager

            // Check whether the VPN has been configured
            if NEVPNManager.shared().connection.status == .invalid {
                statusChangePublisher.send(.notConfigured)
            }
        }
    }

    deinit {
        stopObservingNotifications()
    }

    // MARK: - Observing VPN Notifications

    private func startObservingNotifications(subscribeToDebugNotifications: Bool) {
        startObservingVPNConfigChanges()
        startObservingVPNStatusChanges()

        if subscribeToDebugNotifications {
            startObservingExtensionResetNotifications()
            startObservingServerSelectionChanges()
        }
    }

    private func startObservingVPNConfigChanges() {
        guard configChangeObserverToken == nil else {
            return
        }

        configChangeObserverToken = notificationCenter.addObserver(forName: .NEVPNConfigurationChange, object: nil, queue: nil) { [weak self] notification in
            guard let self = self,
                let manager = notification.object as? NETunnelProviderManager else {
                return
            }

            self.internalTunnelManager = manager
            self.configChangePublisher.send(())
        }
    }

    private func startObservingVPNStatusChanges() {
        guard statusChangeObserverToken == nil else {
            return
        }

        statusChangeObserverToken = notificationCenter.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
            self?.handleStatusChangeNotification(notification)
        }
    }

    private func startObservingExtensionResetNotifications() {
        notificationCenter.addObserver(self,
                                       selector: #selector(resetExtensionNotification),
                                       name: .NetworkProtectionDebugResetExtension,
                                       object: nil)
    }

    private func startObservingServerSelectionChanges() {
        notificationCenter.addObserver(self,
                                       selector: #selector(serverSelectionChangedNotification),
                                       name: .NetworkProtectionEndpointSelectionChanged,
                                       object: nil)
    }

    private func stopObservingNotifications() {
        stopObservingVPNConfigChanges()
        stopObservingVPNStatusChanges()

        notificationCenter.removeObserver(self, name: .NetworkProtectionDebugResetExtension, object: nil)
        notificationCenter.removeObserver(self, name: .NetworkProtectionEndpointSelectionChanged, object: nil)
    }

    private func stopObservingVPNConfigChanges() {
        guard let token = configChangeObserverToken else {
            return
        }

        notificationCenter.removeObserver(token)
        configChangeObserverToken = nil
    }

    private func stopObservingVPNStatusChanges() {
        guard let token = statusChangeObserverToken else {
            return
        }

        notificationCenter.removeObserver(token)
        statusChangeObserverToken = nil
    }

    // MARK: - Error Reporting

    static let networkProtectionDebugEvents: EventMapping<NetworkProtectionError>? = .init { event, _, _, _ in
        let domainEvent: Pixel.Event

        switch event {
        case .noServerRegistrationInfo:
            domainEvent = .networkProtectionTunnelConfigurationNoServerRegistrationInfo
        case .couldNotSelectClosestServer:
            domainEvent = .networkProtectionTunnelConfigurationCouldNotSelectClosestServer
        case .couldNotGetPeerPublicKey:
            domainEvent = .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey
        case .couldNotGetPeerHostName:
            domainEvent = .networkProtectionTunnelConfigurationCouldNotGetPeerHostName
        case .couldNotGetInterfaceAddressRange:
            domainEvent = .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange

        case .failedToFetchServerList:
            return
        case .failedToParseServerListResponse:
            domainEvent = .networkProtectionClientFailedToParseServerListResponse
        case .failedToEncodeRegisterKeyRequest:
            domainEvent = .networkProtectionClientFailedToEncodeRegisterKeyRequest
        case .failedToFetchRegisteredServers:
            return
        case .failedToParseRegisteredServersResponse:
            domainEvent = .networkProtectionClientFailedToParseRegisteredServersResponse

        case .failedToEncodeServerList:
            domainEvent = .networkProtectionServerListStoreFailedToEncodeServerList
        case .failedToWriteServerList(let eventError):
            domainEvent = .networkProtectionServerListStoreFailedToWriteServerList(error: eventError)
        case .noServerListFound:
            return
        case .failedToReadServerList(let eventError):
            domainEvent = .networkProtectionServerListStoreFailedToReadServerList(error: eventError)

        case .failedToCastKeychainValueToData(let field):
            domainEvent = .networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: field)
        case .keychainReadError(let field, let status):
            domainEvent = .networkProtectionKeychainReadError(field: field, status: status)
        case .keychainWriteError(let field, let status):
            domainEvent = .networkProtectionKeychainWriteError(field: field, status: status)
        case .keychainDeleteError(let field, let status):
            domainEvent = .networkProtectionKeychainDeleteError(field: field, status: status)

        case .unhandledError(function: let function, line: let line, error: let error):
            domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)
        }

        Pixel.fire(domainEvent, includeAppVersionParameter: true)
    }

    // MARK: - Notifications: Handling

    private func handleStatusChangeNotification(_ notification: Notification) {
        guard let session = managedSession(from: notification) else {
            return
        }

        Task { [weak self] in
            guard let self = self else {
                return
            }

            do {
                try await self.handleStatusChange(in: session)
            } catch {
                self.logger.log(error)
            }
        }
    }

    private func handleStatusChange(in session: NETunnelProviderSession) async throws {
        /// Some situations can cause the connection status in the session's manager to be invalid.
        /// This just means we need to reload the manager from preferences.  That will trigger another status change
        /// notification that will provide a valid connection status.
        guard session.manager.connection.status != .invalid else {
            try await session.manager.loadFromPreferences()
            return
        }

        let status = self.connectionStatus(from: session)
        statusChangePublisher.send(status)
    }

    /// Retrieves a session that we are managing.  When we're running as a system extension we'll get notifications
    /// for all VPN connections in the system, so we just want to follow the notifications for the connections we own.
    ///
    private func managedSession(from notification: Notification) -> NETunnelProviderSession? {
        guard let session = (notification.object as? NETunnelProviderSession),
              session.manager.protocolConfiguration is NETunnelProviderProtocol else {
            return nil
        }

        return session

    }

    @objc private func resetExtensionNotification(_ notification: Notification) {
        os_log("Received reset extension notification", log: .networkProtection)

        Task { @MainActor in
            try? await stop()
            try? await internalTunnelManager?.removeFromPreferences()
        }
    }

    /// Signals the Network Protection provider that the preferred server selection changed.
    ///
    /// Because the Network Protection feature caches its tunnel configuration in the Keychain, this function works by stopping the tunnel, removing the Keychain state, waiting briefly to allow the system
    /// to acknowledge that the VPN is no longer running, and then restarting the tunnel.
    ///
    /// - Note: The user's PrivateKey, if it exists, is **not** removed. Instead, the app will ensure that the new server has been registered with that key and register it if it hasn't.
    @objc private func serverSelectionChangedNotification(_ notification: Notification) {
        os_log("Received server selection change notification", log: .networkProtection)

        Task { @MainActor in
            try? await stop()

            NetworkProtectionKeychain.deleteReferences()
            try? await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

            try? await start()
        }
    }

    // MARK: - Tunnel Configuration

    /// Loads the tunnel configuration from the filesystem.
    ///
    private func loadTunnelConfiguration() throws -> TunnelConfiguration? {
        let resolvedDefaultPath = NSString(string: Self.defaultConfigFilePath).expandingTildeInPath

        if let quickConfigFile = ProcessInfo.processInfo.environment[Self.quickConfigFilePathEnvironmentVariable] {
            let quickConfig = try String(contentsOfFile: quickConfigFile)
            let configuration = try TunnelConfiguration(fromWgQuickConfig: quickConfig)
            configuration.name = "DuckDuckGo Network Protection Configuration"

            return configuration
        } else if let defaultQuickConfig = try? String(contentsOfFile: resolvedDefaultPath) {
            let configuration = try TunnelConfiguration(fromWgQuickConfig: defaultQuickConfig)
            configuration.name = "DuckDuckGo Network Protection Configuration"

            return configuration
        }

        return nil
    }

    /// Reloads the tunnel manager from preferences.
    ///
    private func reloadTunnelManager() {
        internalTunnelManager = nil
    }

    /// Setups the tunnel manager if it's not set up already.
    ///
    private func setup(_ tunnelManager: NETunnelProviderManager) async throws {
        if !tunnelManager.isEnabled {
            tunnelManager.isEnabled = true
        }

        if tunnelManager.localizedDescription == nil {
            tunnelManager.localizedDescription = UserText.networkProtectionTunnelName
        }

        if let protocolConfiguration = tunnelManager.protocolConfiguration as? NETunnelProviderProtocol,
           protocolConfiguration.verifyConfigurationReference() {
            return
        }

        if let debugTunnelConfiguration = try loadTunnelConfiguration() {
            os_log("Loading tunnel configuration from Debug path", log: .networkProtection)

            tunnelManager.protocolConfiguration = await NETunnelProviderProtocol(tunnelConfiguration: debugTunnelConfiguration,
                                                                                 previouslyFrom: tunnelManager.protocolConfiguration)
        } else {
            let preferredServerName = selectedServerStore.selectedServer.stringValue

            guard let configurationResult = await deviceManager.generateTunnelConfiguration(preferredServerName: preferredServerName) else {
                assertionFailure("Failed to generate tunnel configuration")
                return
            }

            let serverLocation = configurationResult.1.serverLocation
            selectedServerStore.mostRecentlyConnectedServerLocation = serverLocation
            os_log("Generated tunnel configuration for server at location: %{public}s (preferred server is %{public}s)",
                   log: .networkProtection,
                   serverLocation,
                   preferredServerName ?? "Automatic")

            tunnelManager.protocolConfiguration = await NETunnelProviderProtocol(tunnelConfiguration: configurationResult.0,
                                                                                 previouslyFrom: tunnelManager.protocolConfiguration)
        }

    }

    // MARK: - Connection Status Querying

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    func isConnected() async -> Bool {
        guard let tunnelManager = await tunnelManager else {
            return false
        }

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            return true
        default:
            return false
        }
    }

    // MARK: - Starting & Stopping the VPN

    /// Starts the VPN connection used for Network Protection
    ///
    func start() async throws {
        let tunnelManager = try await loadOrMakeTunnelManager()

        switch tunnelManager.connection.status {
        case .invalid:
            reloadTunnelManager()
            try await start()
        case .disconnected, .disconnecting:
            try tunnelManager.connection.startVPNTunnel()
        default:
            // Intentional no-op
            break
        }
    }

    /// Stops the VPN connection used for Network Protection
    ///
    func stop() async throws {
        guard let tunnelManager = await tunnelManager else {
            return
        }

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            tunnelManager.connection.stopVPNTunnel()
        default:
            break
        }
    }

    // MARK: - Connection Status

    private func connectionStatus(from session: NETunnelProviderSession) -> NetworkProtectionConnectionStatus {
        let internalStatus = session.status
        let status: NetworkProtectionConnectionStatus

        switch internalStatus {
        case .connected:
            // In theory when the connection has been established, the date should be set.  But in a worst-case
            // scenario where for some reason the date is missing, we're going to just use Date() as the connection
            // has just started and it's a decent approximation.
            let connectedDate = session.connectedDate ?? Date()
            let serverAddress = session.manager.protocolConfiguration?.serverAddress ?? UserText.networkProtectionServerAddressUnknown

            if let serverLocation = selectedServerStore.mostRecentlyConnectedServerLocation {
                status = .connected(connectedDate: connectedDate, serverAddress: serverAddress, serverLocation: serverLocation)
            } else {
                status = .connected(connectedDate: connectedDate, serverAddress: serverAddress, serverLocation: "Unknown Server Location")
            }
        case .connecting, .reasserting:
            status = .connecting
        case .disconnected, .invalid:
            status = .disconnected
        case .disconnecting:
            // In theory when the connection has been established, the date should be set.  But in a worst-case
            // scenario where for some reason the date is missing, we're going to just use Date() as the connection
            // has just started and it's a decent approximation.
            let connectedDate = session.connectedDate ?? Date()
            let serverAddress = session.manager.protocolConfiguration?.serverAddress ?? UserText.networkProtectionServerAddressUnknown

            if let serverLocation = selectedServerStore.mostRecentlyConnectedServerLocation {
                status = .disconnecting(connectedDate: connectedDate, serverAddress: serverAddress, serverLocation: serverLocation)
            } else {
                status = .disconnecting(connectedDate: connectedDate, serverAddress: serverAddress, serverLocation: "Unknown Server Location")
            }
        @unknown default:
            status = .unknown
        }

        return status
    }
}
