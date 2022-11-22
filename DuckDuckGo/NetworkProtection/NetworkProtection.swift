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

final class NetworkProtection: ObservableObject {

    private lazy var interfaceConfiguration: InterfaceConfiguration = {
        let privateKey = PrivateKey(base64Key: "3+K8uIBcVwqqAmC5QFJg6pOCBzFFwJ3CDyqMzaPhom0=")!
        let addressRange = IPAddressRange(from: "10.64.158.41/32")! // ,fc00:bbbb:bbbb:bb01::1:9e28/128
        let dnsServerIPAddress = IPv4Address("10.64.0.1")!
        let dnsServer = DNSServer(address: dnsServerIPAddress)

        var configuration = InterfaceConfiguration(privateKey: privateKey)
        configuration.addresses = [addressRange]
        configuration.dns = [dnsServer]

        return configuration
    }()

    private lazy var peerConfiguration: PeerConfiguration = {
        let publicKey = PublicKey(base64Key: "F4Scn2i1IIHTsWsCfXesNb2XYyrIu8Wn+vJihvPVk2M=")!
        let addressRange = IPAddressRange(from: "0.0.0.0/0")! // ,::0/0
        let endpoint = Endpoint(from: "37.120.201.82:51820")
        var configuration = PeerConfiguration(publicKey: publicKey)

        configuration.allowedIPs = [addressRange]
        configuration.endpoint = endpoint

        return configuration
    }()

    private lazy var tunnelConfiguration: TunnelConfiguration = {
        TunnelConfiguration(name: "Test tunnel",
                            interface: interfaceConfiguration,
                            peers: [peerConfiguration])
    }()

    private let tunnelManager: NETunnelProviderManager

    init() async {
        if let tunnelManager = try? await NETunnelProviderManager.loadAllFromPreferences().first {
            self.tunnelManager = tunnelManager
        } else {
            tunnelManager = NETunnelProviderManager()
            tunnelManager.protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration, previouslyFrom: nil)
            tunnelManager.isEnabled = true
            tunnelManager.localizedDescription = UserText.networkProtectionTunnelName
        }
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
