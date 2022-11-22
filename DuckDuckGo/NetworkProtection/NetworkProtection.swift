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

extension NETunnelProviderProtocol {
    convenience init?(tunnelConfiguration: TunnelConfiguration, previouslyFrom old: NEVPNProtocol? = nil) {
        self.init()

        guard let name = tunnelConfiguration.name else {
            return nil
        }

        providerBundleIdentifier = "com.duckduckgo.network.protection.network-extension"
        passwordReference = Keychain.makeReference(containing: tunnelConfiguration.asWgQuickConfig(), called: name, previouslyReferencedBy: old?.passwordReference)
        if passwordReference == nil {
            return nil
        }
        #if os(macOS)
        providerConfiguration = ["UID": getuid()]
        #endif

        let endpoints = tunnelConfiguration.peers.compactMap { $0.endpoint }
        if endpoints.count == 1 {
            serverAddress = endpoints[0].stringRepresentation
        } else if endpoints.isEmpty {
            serverAddress = "Unspecified"
        } else {
            serverAddress = "Multiple endpoints"
        }
    }

    func destroyConfigurationReference() {
        guard let ref = passwordReference else { return }
        Keychain.deleteReference(called: ref)
    }

    func verifyConfigurationReference() -> Bool {
        guard let ref = passwordReference else { return false }
        return Keychain.verifyReference(called: ref)
    }

    @discardableResult
    func migrateConfigurationIfNeeded(called name: String) -> Bool {
        /* This is how we did things before we switched to putting items
         * in the keychain. But it's still useful to keep the migration
         * around so that .mobileconfig files are easier.
         */
        if let oldConfig = providerConfiguration?["WgQuickConfig"] as? String {
            #if os(macOS)
            providerConfiguration = ["UID": getuid()]
            #elseif os(iOS)
            providerConfiguration = nil
            #else
            #error("Unimplemented")
            #endif
            guard passwordReference == nil else { return true }
            //wg_log(.info, message: "Migrating tunnel configuration '\(name)'")
            passwordReference = Keychain.makeReference(containing: oldConfig, called: name)
            return true
        }
        #if os(macOS)
        if passwordReference != nil && providerConfiguration?["UID"] == nil && verifyConfigurationReference() {
            providerConfiguration = ["UID": getuid()]
            return true
        }
        #elseif os(iOS)
        if #available(iOS 15, *) {
            /* Update the stored reference from the old iOS 14 one to the canonical iOS 15 one.
             * The iOS 14 ones are 96 bits, while the iOS 15 ones are 160 bits. We do this so
             * that we can have fast set exclusion in deleteReferences safely. */
            if passwordReference != nil && passwordReference!.count == 12 {
                var result: CFTypeRef?
                let ret = SecItemCopyMatching([kSecValuePersistentRef: passwordReference!,
                                               kSecReturnPersistentRef: true] as CFDictionary,
                                               &result)
                if ret != errSecSuccess || result == nil {
                    return false
                }
                guard let newReference = result as? Data else { return false }
                if !newReference.elementsEqual(passwordReference!) {
                    wg_log(.info, message: "Migrating iOS 14-style keychain reference to iOS 15-style keychain reference for '\(name)'")
                    passwordReference = newReference
                    return true
                }
            }
        }
        #endif
        return false
    }
}

final class NetworkProtection: NETunnelProviderManager, ObservableObject {
    private lazy var interfaceConfiguration: InterfaceConfiguration = {
        let privateKey = PrivateKey(base64Key: "aEjzbMK7P/jzKo/hDatqn3dlvPcupT2zq45UZU25P0E=")!
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

    private lazy var adapter: WireGuardAdapter = {
        let tunnelProvider = NEPacketTunnelProvider()
        let logHandler = { (level: WireGuardLogLevel, message: String) -> Void in
            print("LOG: [\(level)] \(message)")
        }

        return WireGuardAdapter(with: tunnelProvider, logHandler: logHandler)
    }()

    override init() {
        super.init()

        protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration, previouslyFrom: nil)
    }

    func setTunnelConfiguration(_ tunnelConfiguration: TunnelConfiguration) {
        protocolConfiguration = NETunnelProviderProtocol(tunnelConfiguration: tunnelConfiguration, previouslyFrom: protocolConfiguration)
        localizedDescription = tunnelConfiguration.name
        //objc_setAssociatedObject(self, &NETunnelProviderManager.cachedConfigKey, tunnelConfiguration, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func start() {
        // This is currently duplicating the configuration.  We are probably not setting an identifier properly.
        saveToPreferences() { error in
            if let error = error {
                print("🔴 Error saving the VPN tunnel: \(error)")
                return
            }

            // The connection won't work until we load it from preferences...
            // Really?! https://stackoverflow.com/a/47569982/712306
            self.loadFromPreferences { error in
                if let error = error {
                    print("🔴 Error loading the VPN tunnel: \(error)")
                    return
                }

                do {
                    guard let session = self.connection as? NETunnelProviderSession else {
                        print("🔴 Error: unexpected nil tunnel provider session")
                        print("Manager configuration: \(self)")
                        return
                    }

                    try session.startTunnel()
                } catch {
                    print("🔴 Error starting the VPN tunnel: \(error)")
                    print("Manager configuration: \(self)")
                }
            }
        }
    }
}
