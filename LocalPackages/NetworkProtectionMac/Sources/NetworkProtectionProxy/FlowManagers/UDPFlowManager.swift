//
//  UDPFlowManager.swift
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

final class UDPFlowManager {
    private let flow: NEAppProxyUDPFlow

    init(flow: NEAppProxyUDPFlow) {
        self.flow = flow
    }

    func start(interface: NWInterface, initialRemoteEndpoint remoteEndpoint: NWEndpoint) async {
        guard let remoteEndpoint = remoteEndpoint as? NWHostEndpoint else {
            os_log("🤌 Remote endpoint is not a host")
            return
        }

        os_log("🤌 Interface %{public}@", String(describing: flow.networkInterface))
        os_log("🤌 New interface %{public}@", String(describing: flow.networkInterface))

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

    private func connectAndStartRunLoop(remoteEndpoint: NWHostEndpoint, interface: NWInterface) async {
        do {
            os_log("🤌 Establishing UDP proxy connection to remote: %{public}@", String(describing: remoteEndpoint))
            let remoteConnection = try await connect(to: remoteEndpoint, interface: interface) //, metadataParameters: metadataParameters)
            //let localHost = (remoteConnection.currentPath?.localEndpoint as? NWHostEndpoint)!.hostname
            //let localPort = (remoteConnection.currentPath?.localEndpoint as? NWHostEndpoint)!.port

            try await flow.open(withLocalEndpoint: nil)
            try await startDataCopyLoop(for: remoteConnection, remoteEndpoint: remoteEndpoint)

            flow.closeReadWithError(nil)
            flow.closeWriteWithError(nil)
        } catch {
            os_log("🤌 UDP Proxy routing failed with error %{public}@", String(describing: error))
            flow.closeReadWithError(error)
            flow.closeWriteWithError(error)
        }
    }

    private func startDataCopyLoop(for remoteConnection: NWConnection, remoteEndpoint: NWHostEndpoint) async throws {
        os_log("🤌 Starting UDP data copy loop")

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                do {
                    while true {
                        guard let self else {
                            throw RemoteConnectionError.cancelled
                        }

                        try Task.checkCancellation()
                        try await self.copyOutoundTraffic(to: remoteConnection)
                    }
                } catch {
                    remoteConnection.forceCancel()
                    os_log("🤌 [UDP] Closing outbound")
                }
            }

            group.addTask { [weak self] in
                do {
                    while true {
                        guard let self else {
                            throw RemoteConnectionError.cancelled
                        }

                        try Task.checkCancellation()
                        try await self.copyInboundTraffic(from: remoteConnection, remoteEndpoint: remoteEndpoint)
                    }
                } catch {
                    remoteConnection.forceCancel()
                    os_log("🤌 [UDP] Closing inbound")
                }
            }

            await group.waitForAll()
        }
    }

    enum RemoteConnectionError: Error {
        case cancelled
        case couldNotEstablishConnection(_ error: Error)
        case unhandledError(_ error: Error)
    }

    func connect(to remoteEndpoint: NWHostEndpoint, interface: NWInterface /*, metadataParameters: nw_parameters_t*/) async throws -> Network.NWConnection {

        let host = Network.NWEndpoint.Host(remoteEndpoint.hostname)
        let port = Network.NWEndpoint.Port(remoteEndpoint.port)!

        os_log("🤌 Interface (UDP) %{public}@", String(describing: interface))

        let parameters = NWParameters.udp
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

        os_log("🤌 Host (UDP) %{public}@", remoteEndpoint.hostname)
        os_log("🤌 Port (UDP) %{public}@", remoteEndpoint.port)

        let connection = NWConnection(host: host, port: port, using: parameters)

        os_log("🤌 Starting UDP connection %{public}@", String(describing: connection))

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        os_log("🤌 UDP Connection ready")
                        connection.stateUpdateHandler = nil
                        continuation.resume()
                    case .cancelled:
                        os_log("🤌 UDP Connection cancelled")
                        connection.stateUpdateHandler = nil
                        continuation.resume(throwing: RemoteConnectionError.cancelled)
                    case .failed(let error):
                        os_log("🤌 UDP Connection failed with error %{public}@", String(describing: error))
                        connection.stateUpdateHandler = nil
                        continuation.resume(throwing: RemoteConnectionError.couldNotEstablishConnection(error))
                    default:
                        break
                    }
                }
            }
            connection.start(queue: .global())
        } onCancel: {
            connection.forceCancel()
        }

        return connection
    }

    func copyInboundTraffic(from remoteConnection: NWConnection, remoteEndpoint: NWHostEndpoint) async throws {

        //os_log("🤌 ⬅️ Copying UDP inbound traffic")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            remoteConnection.receiveMessage { [weak self] data, contentContext, isComplete, error in

                guard let self else {
                    continuation.resume(throwing: RemoteConnectionError.cancelled)
                    return
                }

                switch (data, isComplete, error) {
                case (let data?, _, _):
                    flow.writeDatagrams([data], sentBy: [remoteEndpoint]) { writeError in
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
        //os_log("🤌 ⬅️ Copying UDP outbound traffic")

        let (datagrams, endpoints, error) = await read()

        if let datagrams,
           let endpoints {

            if datagrams.isEmpty {
                throw NEAppProxyFlowError(.aborted)
            }

            for (datagram, endpoint) in zip(datagrams, endpoints) {
                //let connection = NWConnection(to: endpoint, using: .udp)
                try await send(datagram: datagram, through: remoteConnection)
            }
        }

        if let error {
            throw error
        }
    }

    private func read() async -> (datagrams: [Data]?, endpoints: [NWEndpoint]?, error: Error?) {
        await withCheckedContinuation { (continuation: CheckedContinuation<([Data]?, [NWEndpoint]?, Error?), Never>) in
            flow.readDatagrams { datagrams, endpoints, error in
                continuation.resume(returning: (datagrams, endpoints, error))
            }
        }
    }

    private func send(datagram: Data, through remoteConnection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            remoteConnection.send(content: datagram, completion: .contentProcessed({ error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }))
        }
    }
}

extension UDPFlowManager: Hashable {
    static func == (lhs: UDPFlowManager, rhs: UDPFlowManager) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(flow)
    }
}
