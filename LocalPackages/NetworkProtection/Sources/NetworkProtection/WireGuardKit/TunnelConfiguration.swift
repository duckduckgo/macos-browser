// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation

public final class TunnelConfiguration {
    public var name: String?
    public var interface: InterfaceConfiguration
    public let peers: [PeerConfiguration]
    public let tunnelThroughTCP: Bool

    public init(name: String?, interface: InterfaceConfiguration, tunnelThroughTCP: Bool, peers: [PeerConfiguration]) {
        self.interface = interface
        self.peers = peers
        self.name = name
        self.tunnelThroughTCP = tunnelThroughTCP

        let peerPublicKeysArray = peers.map { $0.publicKey }
        let peerPublicKeysSet = Set<PublicKey>(peerPublicKeysArray)
        if peerPublicKeysArray.count != peerPublicKeysSet.count {
            fatalError("Two or more peers cannot have the same public key")
        }
    }
}

extension TunnelConfiguration: Equatable {
    public static func == (lhs: TunnelConfiguration, rhs: TunnelConfiguration) -> Bool {
        return lhs.name == rhs.name &&
            lhs.interface == rhs.interface &&
            Set(lhs.peers) == Set(rhs.peers) &&
            lhs.tunnelThroughTCP == rhs.tunnelThroughTCP
    }
}
