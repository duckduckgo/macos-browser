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
import OSLog

final class NetworkProtection {

    typealias ConnectionChangeHandler = (ConnectionChange) -> Void

    enum QuickConfigLoadingError: Error {
        case quickConfigFilePathEnvVarMissing
    }

    enum ConnectionChange {
        case status(newStatus: NEVPNStatus)
        case configuration
    }

    private var statusChangeOberverToken: NSObjectProtocol?
    private var configurationChangeObserverToken: NSObjectProtocol?

    /// The notification center to use to observe tunnel change notifications.
    ///
    private let notificationCenter: NotificationCenter

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
                internalTunnelManager = tunnelManager

                try await setup(tunnelManager)

                return tunnelManager
            }

            return tunnelManager
        }
    }

    var onConnectionChange: ConnectionChangeHandler?

    // MARK: - Initialization & deinitialization

    /// Default initializer
    ///
    /// - Parameters:
    ///         - notificationCenter: overrideable for testing.  Don't override in production code.
    ///
    init(notificationCenter: NotificationCenter = .default) {
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
        guard configurationChangeObserverToken == nil else {
            return
        }

        configurationChangeObserverToken = notificationCenter.addObserver(forName: .NEVPNConfigurationChange, object: nil, queue: nil) { [weak self] _ in

            guard let self = self else {
                return
            }

            Task {
                do {
                    try await self.reloadTunnelManager()
                } catch {
                    let errorMessage = StaticString(stringLiteral: "🔴 Error reloading the tunnel after a configuration change")
                    assertionFailure(String("\(errorMessage)"))
                    os_log(errorMessage, type: .error)
                }

                self.onConnectionChange?(.configuration)
            }
        }
    }

    private func startObservingVPNStatusChanges() {
        guard statusChangeOberverToken == nil else {
            return
        }

        statusChangeOberverToken = notificationCenter.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] _ in

            guard let self = self,
                  let onConnectionChange = self.onConnectionChange else {
                return
            }

            Task {
                do {
                    let tunnelManager = try await self.tunnelManager
                    onConnectionChange(.status(newStatus: tunnelManager.connection.status))
                } catch {
                    let error = StaticString(stringLiteral: "🔴 Error obtaining the tunnel manager")

                    assertionFailure("\(error)")
                    os_log(error, type: .error)
                }
            }
        }
    }

    private func stopObservingNotifications() {
        stopObservingVPNConfigChanges()
        stopObservingVPNStatusChanges()
    }

    private func stopObservingVPNConfigChanges() {
        guard let token = configurationChangeObserverToken else {
            return
        }

        notificationCenter.removeObserver(token)
        configurationChangeObserverToken = nil
    }

    private func stopObservingVPNStatusChanges() {
        guard let token = statusChangeOberverToken else {
            return
        }

        notificationCenter.removeObserver(token)
        statusChangeOberverToken = nil
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
    private func reloadTunnelManager() async throws {
        // Doing this ensures the tunnel will be reloaded
        internalTunnelManager = nil
    }

    /// Setups the tunnel manager if it's not set up already.
    ///
    private func setup(_ tunnelManager: NETunnelProviderManager) async throws {
        guard tunnelManager.protocolConfiguration as? NETunnelProviderProtocol != nil else {
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
            try await tunnelManager.loadFromPreferences()
            try tunnelManager.connection.startVPNTunnel()
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
