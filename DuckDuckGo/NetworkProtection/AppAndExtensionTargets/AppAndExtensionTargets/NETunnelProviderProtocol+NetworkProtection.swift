//
//  NETunnelProviderProtocol+NetworkProtection.swift
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
import NetworkExtension
import NetworkProtection

extension NETunnelProviderProtocol {
    @MainActor
    convenience init?(tunnelConfiguration: TunnelConfiguration, previouslyFrom old: NEVPNProtocol? = nil, extensionBundleIdentifier: String) {
        self.init()

        guard let name = tunnelConfiguration.name else {
            return nil
        }

        #if NETP_SYSTEM_EXTENSION
        providerBundleIdentifier = extensionBundleIdentifier
        passwordReference = NetworkProtectionKeychain.makeReference(containing: tunnelConfiguration.asWgQuickConfig(),
                                                                    useSystemKeychain: true,
                                                                    called: name,
                                                                    previouslyReferencedBy: old?.passwordReference)
        #else
        providerBundleIdentifier = extensionBundleIdentifier
        passwordReference = NetworkProtectionKeychain.makeReference(containing: tunnelConfiguration.asWgQuickConfig(),
                                                                    useSystemKeychain: false,
                                                                    called: name,
                                                                    previouslyReferencedBy: old?.passwordReference)
        #endif

        if passwordReference == nil {
            return nil
        }

        #if os(macOS)
        providerConfiguration = ["UID": getuid(), "WgQuickConfig": tunnelConfiguration.asWgQuickConfig()]
        #endif

        let endpoints = tunnelConfiguration.peers.compactMap(\.endpoint)
        if endpoints.count == 1 {
            serverAddress = endpoints[0].description
        } else if endpoints.isEmpty {
            serverAddress = "Unspecified"
        } else {
            serverAddress = "Multiple endpoints"
        }
    }

    func destroyConfigurationReference() {
        guard let ref = passwordReference else { return }
        NetworkProtectionKeychain.deleteReference(called: ref)
    }

    func verifyConfigurationReference() -> Bool {
        guard let ref = passwordReference else {
            return false
        }

        let result = NetworkProtectionKeychain.verifyReference(called: ref)
        return result
    }

}
