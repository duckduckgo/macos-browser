// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import NetworkExtension
import NetworkProtection
import os

enum PacketTunnelProviderError: String, Error {
    case savedProtocolConfigurationIsInvalid
    case dnsResolutionFailure
    case couldNotStartBackend
    case couldNotDetermineFileDescriptor
    case couldNotSetNetworkSettings
}

extension NETunnelProviderProtocol {
    func asTunnelConfiguration(called name: String? = nil) -> TunnelConfiguration? {
        if let passwordReference = passwordReference,
            let config = NetworkProtectionKeychain.openReference(called: passwordReference) {
            return try? TunnelConfiguration(fromWgQuickConfig: config, called: name)
        }
        if let oldConfig = providerConfiguration?["WgQuickConfig"] as? String {
            return try? TunnelConfiguration(fromWgQuickConfig: oldConfig, called: name)
        }
   
        return nil
    }
}
