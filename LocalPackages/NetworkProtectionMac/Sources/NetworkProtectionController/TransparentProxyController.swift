//
//  TransparentProxyController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import SystemExtensions

/// Controller for ``TransparentProxyProvider``
///
final class TransparentProxyController {

    typealias ManagerSetupCallback = (_ manager: NETransparentProxyManager) async -> Void

    /// The bundleID of the extension that contains the ``TransparentProxyProvider``.
    ///
    private let extensionID: String

    /// Callback to set up a ``NETransparentProxyManager``.
    ///
    private let setup: ManagerSetupCallback

    /// Default initializer.
    ///
    /// - Parameters:
    ///     - extensionID: the bundleID of the extension containing the ``TransparentProxyProvider``.
    ///         This class DOES NOT take any responsibility in installing the system extension.  It only uses
    ///         the extensionID to identify the appropriate manager configuration to load / save.
    ///     - setup: a callback that will be called whenever a ``NETransparentProxyManager`` needs
    ///         to be setup.
    ///
    init(extensionID: String, setup: @escaping ManagerSetupCallback) {
        self.extensionID = extensionID
        self.setup = setup
    }

    /// Loads the configuration matching our ``extensionID``.
    ///
    func loadExisting() async -> NETransparentProxyManager? {
        try? await NETransparentProxyManager.loadAllFromPreferences().first { manager in
            (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == extensionID
        }
    }

    /// Loads an existing configuration or creates a new one, if one doesn't exist.
    ///
    /// - Returns a properly configured `NETransparentProxyManager`.
    ///
    func loadOrCreateConfiguration() async throws -> NETransparentProxyManager {
        let manager = await loadExisting() ?? NETransparentProxyManager()

        await setup(manager)

        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
        } catch {
            print(error.localizedDescription)
        }

        return manager
    }

    func start(dryMode: Bool) async throws {
        let manager = try await loadOrCreateConfiguration()

        do {
            try manager.connection.startVPNTunnel(options: [
                "dryMode": NSNumber(value: dryMode)
            ])
        } catch {
            print(error.localizedDescription)
        }
    }
/*
    func connect() {
        let connection = NWConnection(to: .hostPort(host: .init("google.com"), port: .init(integerLiteral: 443)), using: .tls)
        self.connection = connection

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connected!")
            case .failed(let error):
                print("Error! \(error.localizedDescription)")
            default:
                print("Something else!")
            }
        }

        connection.start(queue: .global())
    }*/
/*
    private func setup(_ manager: NETransparentProxyManager) {
        manager.localizedDescription = "Diego's transparent proxy"

        if !manager.isEnabled {
            manager.isEnabled = true
        }

        manager.protocolConfiguration = {
            let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
            protocolConfiguration.serverAddress = "127.0.0.1" // Dummy address... the NetP service will take care of grabbing a real server
            protocolConfiguration.providerBundleIdentifier = "com.duckduckgo.DiegoTest.NetworkExtension"

            // always-on
            protocolConfiguration.disconnectOnSleep = false

            // kill switch
            //protocolConfiguration.enforceRoutes = false

            // this setting breaks Connection Tester
            //protocolConfiguration.includeAllNetworks = settings.includeAllNetworks

            // This is intentionally not used but left here for documentation purposes.
            // The reason for this is that we want to have full control of the routes that
            // are excluded, so instead of using this setting we're just configuring the
            // excluded routes through our VPNSettings class, which our extension reads directly.
            // protocolConfiguration.excludeLocalNetworks = settings.excludeLocalNetworks

            return protocolConfiguration
        }()
    }*/
/*
    func sendProviderMessage() async {
        guard let manager = await Self.loadExisting() else {
            return
        }

        guard let session = (manager.connection as? NETunnelProviderSession) else {
            return
        }

        try? session.sendProviderMessage("Hello world!".data(using: .utf8)!)
    }*/
}
