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
import NetworkProtectionUI

/// Takes care of handling incoming IPC requests from clients that need to be relayed to the tunnel, and handling state
/// changes that need to be relayed back to IPC clients.
///
/// This also includes the tunnel settings which are controller through shared `UserDefaults` as a form of IPC.
/// Clients can edit those defaults and this class will observe the changes and relay them to the runnel.
///
final class TunnelControllerIPCService {
    private let tunnelController: NetworkProtectionTunnelController
    private let networkExtensionController: NetworkExtensionController
    private let uninstaller: VPNUninstalling
    private let server: NetworkProtectionIPC.TunnelControllerIPCServer
    private let statusReporter: NetworkProtectionStatusReporter
    private var cancellables = Set<AnyCancellable>()
    private let defaults: UserDefaults

    init(tunnelController: NetworkProtectionTunnelController,
         uninstaller: VPNUninstalling,
         networkExtensionController: NetworkExtensionController,
         statusReporter: NetworkProtectionStatusReporter,
         defaults: UserDefaults = .netP) {

        self.tunnelController = tunnelController
        self.uninstaller = uninstaller
        self.networkExtensionController = networkExtensionController
        server = .init(machServiceName: Bundle.main.bundleIdentifier!)
        self.statusReporter = statusReporter
        self.defaults = defaults

        subscribeToErrorChanges()
        subscribeToStatusUpdates()
        subscribeToServerChanges()
        subscribeToDataVolumeUpdates()

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

    private func subscribeToDataVolumeUpdates() {
        statusReporter.dataVolumeObserver.publisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] dataVolume in
                self?.server.dataVolumeUpdated(dataVolume)
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

    func start(completion: @escaping (Error?) -> Void) {
        Task {
            await tunnelController.start()
        }

        // For IPC requests, completion means the IPC request was processed, and NOT
        // that the requested operation was executed fully.  Failure to complete the
        // operation will be handled entirely within the tunnel controller.
        completion(nil)
    }

    func stop(completion: @escaping (Error?) -> Void) {
        Task {
            await tunnelController.stop()
        }

        // For IPC requests, completion means the IPC request was processed, and NOT
        // that the requested operation was executed fully.  Failure to complete the
        // operation will be handled entirely within the tunnel controller.
        completion(nil)
    }

    func fetchLastError(completion: @escaping (Error?) -> Void) {
        Task {
            guard #available(macOS 13.0, *),
                  let connection = await tunnelController.connection else {

                completion(nil)
                return
            }

            connection.fetchLastDisconnectError(completionHandler: completion)
        }
    }

    func resetAll(uninstallSystemExtension: Bool) async {
        try? await networkExtensionController.deactivateSystemExtension()
    }

    func command(_ command: VPNCommand) async throws {
        try await tunnelController.relay(command)

        switch command {
        case .removeSystemExtension:
            try await uninstaller.removeSystemExtension()
        case .expireRegistrationKey:
            // Intentional no-op: handled by the extension
            break
        case .sendTestNotification:
            // Intentional no-op: handled by the extension
            break
        case .removeVPNConfiguration:
            try await uninstaller.removeVPNConfiguration()
        case .uninstallVPN:
            try await uninstaller.uninstall(includingSystemExtension: true)
        case .disableConnectOnDemandAndShutDown:
            // Not implemented on macOS yet
            break
        }
    }
}
