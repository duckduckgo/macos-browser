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
import SwiftUI
import WireGuardKit
import NetworkExtension

final class NetworkProtection {

    typealias StatusChangeHandler = (NEVPNStatus) -> Void
    typealias ConfigChangeHandler = () -> Void

    // MARK: - Errors & Logging

    enum QuickConfigLoadingError: Error {
        case quickConfigFilePathEnvVarMissing
    }

    enum StatusChangeError: Error {
        case couldNotRetrieveStatusFromNotification
    }

    /// The logger that this object will use for errors that are handled by this class.
    ///
    private let logger: NetworkProtectionLogger

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

    /// Callback for VPN configuration changes.
    ///
    var onConfigChange: ConfigChangeHandler?

    /// Callback for VPN status changes.
    ///
    var onStatusChange: StatusChangeHandler?

    // MARK: - VPN Tunnel & Configuration

    /// The environment variable that holds the path to the WG quick configuration file that will be used for the tunnel.
    ///
    static let quickConfigFilePathEnvironmentVariable = "NETP_QUICK_CONFIG_FILE_PATH"

    /// The actual storage for our tunnel manager.
    ///
    private var internalTunnelManager: NETunnelProviderManager?

    /// The tunnel manager to use for the VPN connection.
    ///
    private var tunnelManager: NETunnelProviderManager {
        get async throws {
            guard let tunnelManager = internalTunnelManager else {
                let tunnelManager = try await NETunnelProviderManager.loadAllFromPreferences().first ?? NETunnelProviderManager()
                try await setup(tunnelManager)
                try await tunnelManager.saveToPreferences()
                try await tunnelManager.loadFromPreferences()

                internalTunnelManager = tunnelManager
                return tunnelManager
            }

            return tunnelManager
        }
    }

    // MARK: - Initialization & deinitialization

    /// Default initializer
    ///
    /// - Parameters:
    ///         - notificationCenter: (meant for testing) the notification center that this object will use.
    ///         - logger: (meant for testing) the logger that this object will use.
    ///
    init(notificationCenter: NotificationCenter = .default,
         logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger()) {

        self.logger = logger
        self.notificationCenter = notificationCenter

        startObservingNotifications()
    }

    deinit {
        stopObservingNotifications()
    }

    // MARK: - Observing VPN Notifications

    private func startObservingNotifications() {
        startObservingVPNConfigChanges()
        startObservingVPNStatusChanges()
    }

    private func startObservingVPNConfigChanges() {
        guard configChangeObserverToken == nil else {
            return
        }

        configChangeObserverToken = notificationCenter.addObserver(forName: .NEVPNConfigurationChange, object: nil, queue: nil) { [weak self] _ in

            guard let self = self else {
                return
            }

            self.reloadTunnelManager()
            self.onConfigChange?()
        }
    }

    private func startObservingVPNStatusChanges() {
        guard statusChangeObserverToken == nil else {
            return
        }

        statusChangeObserverToken = notificationCenter.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in

            guard let self = self else {
                return
            }

            guard let status = (notification.object as? NETunnelProviderSession)?.status else {
                self.logger.log(StatusChangeError.couldNotRetrieveStatusFromNotification)
                return
            }

            self.onStatusChange?(status)
        }
    }

    private func stopObservingNotifications() {
        stopObservingVPNConfigChanges()
        stopObservingVPNStatusChanges()
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

    // MARK: - Tunnel Configuration

    /// Loads the tunnel configuration from the filesystem.
    ///
    private func loadTunnelConfiguration() throws -> TunnelConfiguration {
        guard let quickConfigFile = ProcessInfo.processInfo.environment[Self.quickConfigFilePathEnvironmentVariable] else {
            throw QuickConfigLoadingError.quickConfigFilePathEnvVarMissing
        }

        let quickConfig = try String(contentsOfFile: quickConfigFile)

        let configuration = try TunnelConfiguration(fromWgQuickConfig: quickConfig)
        configuration.name = "DuckDuckGo Network Protection Configuration"
        return configuration
    }

    /// Reloads the tunnel manager from preferences.
    ///
    private func reloadTunnelManager() {
        // Doing this ensures the tunnel will be reloaded
        internalTunnelManager = nil
    }

    /// Setups the tunnel manager if it's not set up already.
    ///
    private func setup(_ tunnelManager: NETunnelProviderManager) async throws {
        guard tunnelManager.protocolConfiguration as? NETunnelProviderProtocol == nil else {
            return
        }

        let tunnelConfiguration = try loadTunnelConfiguration()
        tunnelManager.isEnabled = true
        tunnelManager.localizedDescription = UserText.networkProtectionTunnelName
        tunnelManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration, previouslyFrom: nil)
    }

    // MARK: - Connection Status Querying

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    func isConnected() async throws -> Bool {
        let tunnelManager = try await tunnelManager

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
        let tunnelManager = try await tunnelManager

        switch tunnelManager.connection.status {
        case .invalid:
            reloadTunnelManager()
            try await start()
        case .disconnected, .disconnecting:
            try tunnelManager.connection.startVPNTunnel()
        default:
            break
        }
    }

    /// Stops the VPN connection used for Network Protection
    ///
    func stop() async throws {
        let tunnelManager = try await tunnelManager

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            tunnelManager.connection.stopVPNTunnel()
        default:
            break
        }
    }
}
