//
//  TCPFlowManager.swift
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
import OSLog // swiftlint:disable:this enforce_os_log_wrapper

final class TCPFlowManager {
    private let flow: NEAppProxyTCPFlow
    var connections = [nw_connection_t]()

    init(flow: NEAppProxyTCPFlow) {
        self.flow = flow
    }

    func start(interface: NWInterface) async {
        guard let remoteEndpoint = flow.remoteEndpoint as? NWHostEndpoint else {
            os_log("🤌 Remote endpoint is not a host")
            return
        }

        //let endpoint = nw_endpoint_create_host(nwEndpoint.hostname, nwEndpoint.port)

        // Add code here to handle the incoming flow.
        //os_log("🤌 Flow %{public}@", String(describing: flow))
        //os_log("🤌 Metadata %{public}@", String(describing: flow.metaData))
        //os_log("🤌 Interface %{public}@", String(describing: flow.networkInterface))
        //os_log("🤌 New interface %{public}@", String(describing: flow.networkInterface))

        //let metadataParameters = nw_parameters_create_secure_tcp(_nw_parameters_configure_protocol_disable, _nw_parameters_configure_protocol_default_configuration)

        //flow.setMetadata(metadataParameters)
/*
        let endpoint = nw_endpoint_create_host(flow.remoteHostname!, remoteEndpoint.port)
        let connection = nw_connection_create(endpoint, metadataParameters)
        nw_connection_start(connection)
        connections.append(connection)

        try? await flow.open(withLocalEndpoint: nil)
        try? await Task.sleep(nanoseconds: 20 * NSEC_PER_SEC)*/

        //os_log("🤌 Parameters %{public}@", String(describing: metadataParameters))

        await connectAndStartRunLoop(remoteEndpoint: remoteEndpoint, interface: interface) //, metadataParameters: metadataParameters)
    }

    private func connectAndStartRunLoop(remoteEndpoint: NWHostEndpoint, interface: NWInterface) async { //, metadataParameters: nw_parameters_t) async {
        do {
            //os_log("🤌 Establishing proxy connection to remote")
            let remoteConnection = try await connect(to: remoteEndpoint, interface: interface) //, metadataParameters: metadataParameters)
            //let localHost = (remoteConnection.currentPath?.localEndpoint as? NWHostEndpoint)!.hostname
            //let localPort = (remoteConnection.currentPath?.localEndpoint as? NWHostEndpoint)!.port

            try await flow.open(withLocalEndpoint: nil)
            try await startDataCopyLoop(for: remoteConnection)
        } catch {
            //os_log("🤌 Proxy routing failed with error %{public}@", String(describing: error))
            flow.closeReadWithError(error)
            flow.closeWriteWithError(error)
        }
    }

    private func startDataCopyLoop(for remoteConnection: NWConnection) async throws {
        //os_log("🤌 Starting data copy loop")

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                do {
                    while true {
                        try await self?.copyOutoundTraffic(to: remoteConnection)
                    }
                } catch {
                    await self?.closeFlow(remoteConnection: remoteConnection, error: error)
                }
            }

            group.addTask { [weak self] in
                do {
                    while true {
                        try await self?.copyInboundTraffic(from: remoteConnection)
                    }
                } catch {
                    await self?.closeFlow(remoteConnection: remoteConnection, error: error)
                }
            }
        }
    }

    enum RemoteConnectionError: Error {
        case cancelled
        case couldNotEstablishConnection(_ error: Error)
        case unhandledError(_ error: Error)
    }

    @MainActor
    func closeFlow(remoteConnection: NWConnection, error: Error?) {
        remoteConnection.forceCancel()
        flow.closeReadWithError(error)
        flow.closeWriteWithError(error)
    }

    func connect(to remoteEndpoint: NWHostEndpoint, interface: NWInterface /*, metadataParameters: nw_parameters_t*/) async throws -> Network.NWConnection {
        let host = Network.NWEndpoint.Host(remoteEndpoint.hostname)
        let port = Network.NWEndpoint.Port(remoteEndpoint.port)!

        //os_log("🤌 Interface %{public}@", String(describing: interface))

        let parameters = NWParameters.tcp
        parameters.preferNoProxies = true
        parameters.requiredInterface = interface
        parameters.prohibitedInterfaceTypes = [.other]
        /*
        parameters.attribution = {
            switch nw_parameters_get_attribution(metadataParameters) {
            case .user:
                return .user
            case .developer:
                return .developer
            @unknown default:
                assertionFailure()
                return .developer
            }
        }()*/

        //os_log("🤌 Host %{public}@", remoteEndpoint.hostname)
        //os_log("🤌 Port %{public}@", remoteEndpoint.port)

        let connection = NWConnection(host: host, port: port, using: parameters)

        //os_log("🤌 Starting connection %{public}@", String(describing: connection))
        connection.start(queue: .global())

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                connection.stateUpdateHandler = { [weak connection] state in
                    guard let connection else { return }

                    switch state {
                    case .ready:
                        //os_log("🤌 Connection ready")
                        connection.stateUpdateHandler = nil
                        continuation.resume()
                    case .cancelled:
                        //os_log("🤌 Connection cancelled")
                        connection.stateUpdateHandler = nil
                        continuation.resume(throwing: RemoteConnectionError.cancelled)
                    case .failed(let error):
                        //os_log("🤌 Connection failed with error %{public}@", String(describing: error))
                        connection.stateUpdateHandler = nil
                        continuation.resume(throwing: RemoteConnectionError.couldNotEstablishConnection(error))
                    default:
                        break
                    }
                }
            }
        } onCancel: {
            connection.forceCancel()
        }

        return connection
    }

    func copyInboundTraffic(from remoteConnection: NWConnection) async throws {
        //os_log("🤌 ⬅️ Copying inbound traffic")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            remoteConnection.receive(minimumIncompleteLength: 1,
                                     maximumLength: 4096) { [weak flow] (data, _, isComplete, error) in
                guard let flow else {
                    continuation.resume(throwing: RemoteConnectionError.cancelled)
                    return
                }

                switch (data, isComplete, error) {
                case (let data?, _, _):
                    flow.write(data) { writeError in
                        if let writeError {
                            continuation.resume(throwing: writeError)
                        } else {
                            continuation.resume()
                        }
                    }
                case (_, true, _):
                    continuation.resume(throwing: RemoteConnectionError.cancelled)
                case (_, _, let error?):
                    continuation.resume(throwing: RemoteConnectionError.unhandledError(error))
                default:
                    continuation.resume()
                }
            }
        }
    }

    func copyOutoundTraffic(to remoteConnection: NWConnection) async throws {
        //os_log("🤌 ⬅️ Copying outbound traffic")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            flow.readData { data, error in
                if let data {
                    remoteConnection.send(content: data, completion: .contentProcessed({ error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }

                        continuation.resume()
                    }))
                }

                if let error {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension TCPFlowManager: Hashable {
    static func == (lhs: TCPFlowManager, rhs: TCPFlowManager) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(flow)
    }
}
