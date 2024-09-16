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
import PixelKit
import UDSHelper

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
    private let server: NetworkProtectionIPC.VPNControllerXPCServer
    private let statusReporter: NetworkProtectionStatusReporter
    private var cancellables = Set<AnyCancellable>()
    private let defaults: UserDefaults
    private let pixelKit: PixelKit?
    private let udsServer: UDSServer

    enum IPCError: SilentErrorConvertible {
        case versionMismatched

        var asSilentError: KnownFailure.SilentError? {
            switch self {
            case .versionMismatched: return .loginItemVersionMismatched
            }
        }
    }

    enum UDSError: PixelKitEventV2 {
        case udsServerStartFailure(_ error: Error)

        var name: String {
            switch self {
            case .udsServerStartFailure:
                return "vpn_agent_uds_server_start_failure"
            }
        }

        var error: Error? {
            switch self {
            case .udsServerStartFailure(let error):
                return error
            }
        }

        var parameters: [String: String]? {
            return nil
        }
    }

    init(tunnelController: NetworkProtectionTunnelController,
         uninstaller: VPNUninstalling,
         networkExtensionController: NetworkExtensionController,
         statusReporter: NetworkProtectionStatusReporter,
         fileManager: FileManager = .default,
         defaults: UserDefaults = .netP,
         pixelKit: PixelKit? = .shared) {

        self.tunnelController = tunnelController
        self.uninstaller = uninstaller
        self.networkExtensionController = networkExtensionController
        server = .init(machServiceName: Bundle.main.bundleIdentifier!)
        self.statusReporter = statusReporter
        self.defaults = defaults
        self.pixelKit = pixelKit

        udsServer = UDSServer(socketFileURL: VPNIPCResources.socketFileURL)

        subscribeToErrorChanges()
        subscribeToStatusUpdates()
        subscribeToServerChanges()
        subscribeToKnownFailureUpdates()
        subscribeToDataVolumeUpdates()

        server.serverDelegate = self
    }

    public func activate() {
        server.activate()

        do {
            try udsServer.start { [weak self] message in
                guard let self else { return nil }

                let command = try JSONDecoder().decode(VPNIPCClientCommand.self, from: message)

                switch command {
                case .uninstall(let component):
                    try await uninstall(component)
                    return nil
                case .quit:
                    quitAgent()
                    return nil
                }
            }
        } catch {
            pixelKit?.fire(UDSError.udsServerStartFailure(error))
            assertionFailure(error.localizedDescription)
        }
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

    private func subscribeToKnownFailureUpdates() {
        statusReporter.knownFailureObserver.publisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] failure in
                self?.server.knownFailureUpdated(failure)
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

extension TunnelControllerIPCService: XPCServerInterface {

    func register(completion: @escaping (Error?) -> Void) {
        register(version: version, bundlePath: bundlePath, completion: completion)
    }

    func register(version: String, bundlePath: String, completion: @escaping (Error?) -> Void) {
        server.serverInfoChanged(statusReporter.serverInfoObserver.recentValue)
        server.statusChanged(statusReporter.statusObserver.recentValue)
        if self.version != version {
            let error = TunnelControllerIPCService.IPCError.versionMismatched
            NetworkProtectionKnownFailureStore().lastKnownFailure = KnownFailure(error)
            completion(error)
        } else {
            completion(nil)
        }
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
            try await uninstall(.systemExtension)
        case .expireRegistrationKey:
            // Intentional no-op: handled by the extension
            break
        case .sendTestNotification:
            // Intentional no-op: handled by the extension
            break
        case .removeVPNConfiguration:
            try await uninstall(.configuration)
        case .restartAdapter:
            // Intentional no-op: handled by the extension
            break
        case .uninstallVPN:
            try await uninstall(.all)
        case .disableConnectOnDemandAndShutDown:
            // Not implemented on macOS yet
            break
        case .quitAgent:
            quitAgent()
        }
    }

    private func uninstall(_ component: VPNUninstallComponent) async throws {
        switch component {
        case .all:
            try await uninstaller.uninstall(includingSystemExtension: true)
        case .configuration:
            try await uninstaller.removeVPNConfiguration()
        case .systemExtension:
            try await uninstaller.removeSystemExtension()
        }
    }

    private func quitAgent() {
        exit(EXIT_SUCCESS)
    }
}

// MARK: - Error Handling

extension TunnelControllerIPCService.IPCError: LocalizedError, CustomNSError {
    var errorDescription: String? {
        switch self {
        case .versionMismatched: return "Login item version mismatched"
        }
    }

    var errorCode: Int {
        switch self {
        case .versionMismatched: return 0
        }
    }

    var errorUserInfo: [String: Any] {
        switch self {
        case .versionMismatched: return [:]
        }
    }
}
