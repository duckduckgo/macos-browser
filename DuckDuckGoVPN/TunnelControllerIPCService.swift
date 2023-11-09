//
//  TunnelControllerIPCService.swift
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

import Combine
import Foundation
import NetworkProtection
import NetworkProtectionIPC

/// Takes care of handling incoming IPC requests from clients that need to be relayed to the tunnel, and handling state
/// changes that need to be relayed back to IPC clients.
///
/// This also includes the tunnel settings which are controller through shared `UserDefaults` as a form of IPC.
/// Clients can edit those defaults and this class will observe the changes and relay them to the runnel.
///
final class TunnelControllerIPCService {
    private let tunnelController: TunnelController
    private let networkExtensionController: NetworkExtensionController
    private let server: NetworkProtectionIPC.TunnelControllerIPCServer
    private let statusReporter: NetworkProtectionStatusReporter
    private var cancellables = Set<AnyCancellable>()

    init(tunnelController: TunnelController,
         networkExtensionController: NetworkExtensionController,
         statusReporter: NetworkProtectionStatusReporter) {

        self.tunnelController = tunnelController
        self.networkExtensionController = networkExtensionController
        server = .init(machServiceName: Bundle.main.bundleIdentifier!)
        self.statusReporter = statusReporter

        subscribeToErrorChanges()
        subscribeToStatusUpdates()
        subscribeToServerChanges()

        server.serverDelegate = self
    }

    public func activate() {
        server.activate()
    }

    private func subscribeToErrorChanges() {
        statusReporter.connectionErrorObserver.publisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.server.errorChanged(error)
            }
            .store(in: &cancellables)
    }

    private func subscribeToServerChanges() {
        statusReporter.serverInfoObserver.publisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] serverInfo in
                self?.server.serverInfoChanged(serverInfo)
            }
            .store(in: &cancellables)
    }

    private func subscribeToStatusUpdates() {
        statusReporter.statusObserver.publisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.server.statusChanged(status)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Requests from the client

extension TunnelControllerIPCService: IPCServerInterface {

    func register() {
        server.serverInfoChanged(statusReporter.serverInfoObserver.recentValue)
        server.statusChanged(statusReporter.statusObserver.recentValue)
    }

    func start() {
        Task {
            await tunnelController.start()
        }
    }

    func stop() {
        Task {
            await tunnelController.stop()
        }
    }

    func resetAll(uninstallSystemExtension: Bool) async {
        try? await networkExtensionController.deactivateSystemExtension()
    }

    func debugCommand(_ command: DebugCommand) async {
        if let activeSession = try? await ConnectionSessionUtilities.activeSession(networkExtensionBundleID: Bundle.main.networkExtensionBundleID) {

            // First give a chance to the extension to process the command, since some commands
            // may remove the VPN configuration or deactivate the extension.
            try? await activeSession.sendProviderRequest(.debugCommand(command))
        }

        switch command {
        case .removeSystemExtension:
            await VPNConfigurationManager().removeVPNConfiguration()
            try? await networkExtensionController.deactivateSystemExtension()
        case .expireRegistrationKey: fallthrough
        case .sendTestNotification:
            // Intentional no-op: handled by the extension
            break
        case .removeVPNConfiguration:
            await VPNConfigurationManager().removeVPNConfiguration()
        }
    }
}
