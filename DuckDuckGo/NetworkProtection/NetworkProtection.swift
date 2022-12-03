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

import SwiftUI
import WireGuardKit
import NetworkExtension
import OSLog

final class NetworkProtection: ObservableObject {

    enum QuickConfigLoadingError: Error {
        case quickConfigFilePathEnvVarMissing
    }

    static let quickConfigFilePathEnvironmentVariable = "NETP_QUICK_CONFIG_FILE_PATH"
    private let tunnelManager: NETunnelProviderManager

    init() async throws {
        tunnelManager = try await NETunnelProviderManager.loadAllFromPreferences().first ?? NETunnelProviderManager()
        try await setupTunnelManager()
    }

    // MARK: - Tunnel Configuration

    /// Loads the tunnel configuration from the filesystem.
    ///
    func loadTunnelConfiguration() throws -> TunnelConfiguration {
        guard let quickConfigFile = ProcessInfo.processInfo.environment[Self.quickConfigFilePathEnvironmentVariable] else {

            throw QuickConfigLoadingError.quickConfigFilePathEnvVarMissing
        }

        let quickConfig = try String(contentsOfFile: quickConfigFile)

        let configuration = try TunnelConfiguration(fromWgQuickConfig: quickConfig)
        configuration.name = "DuckDuckGo Network Protection Configuration"
        return configuration
    }

    // MARK: - Tunnel Manager Configuration

    func setupTunnelManager() async throws {
        let tunnelConfiguration = try loadTunnelConfiguration()

        if tunnelManager.protocolConfiguration as? NETunnelProviderProtocol == nil {
            tunnelManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration, previouslyFrom: nil)
        }

        tunnelManager.isEnabled = true
        tunnelManager.localizedDescription = UserText.networkProtectionTunnelName

        try await tunnelManager.saveToPreferences()
    }

    // MARK: - Connection Status Querying

    func isConnected() -> Bool {
        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            return true
        default:
            return false
        }
    }

    // MARK: - Starting & Stopping the connection

    func start() async throws {
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

    func stop() throws {
        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            tunnelManager.connection.stopVPNTunnel()
        default:
            break
        }
    }
}
