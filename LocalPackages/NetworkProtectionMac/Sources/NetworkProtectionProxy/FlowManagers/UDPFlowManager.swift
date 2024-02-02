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
            return
        }

        await connectAndStartRunLoop(remoteEndpoint: remoteEndpoint, interface: interface)
    }

    private func connectAndStartRunLoop(remoteEndpoint: NWHostEndpoint, interface: NWInterface) async {
        do {
            let remoteConnection = try await connect(to: remoteEndpoint, interface: interface)

            try await flow.open(withLocalEndpoint: nil)
            try await startDataCopyLoop(for: remoteConnection, remoteEndpoint: remoteEndpoint)

            flow.closeReadWithError(nil)
            flow.closeWriteWithError(nil)
        } catch {
            flow.closeReadWithError(error)
            flow.closeWriteWithError(error)
        }
    }

    private func startDataCopyLoop(for remoteConnection: NWConnection, remoteEndpoint: NWHostEndpoint) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                while true {
                    guard let self else {
                        throw RemoteConnectionError.cancelled
                    }

                    try Task.checkCancellation()
                    try await self.copyOutoundTraffic(to: remoteConnection)
                }
            }

            group.addTask { [weak self] in
                while true {
                    guard let self else {
                        throw RemoteConnectionError.cancelled
                    }

                    try Task.checkCancellation()
                    try await self.copyInboundTraffic(from: remoteConnection, remoteEndpoint: remoteEndpoint)
                }
            }

            while !group.isEmpty {
                 do {
                     try await group.next()

                 } catch {
                     group.cancelAll()
                     throw error
                 }
            }
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

        let parameters = NWParameters.udp
        parameters.preferNoProxies = true
        parameters.requiredInterface = interface
        parameters.prohibitedInterfaceTypes = [.other]

        let connection = NWConnection(host: host, port: port, using: parameters)

        try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume()
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: RemoteConnectionError.cancelled)
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: RemoteConnectionError.couldNotEstablishConnection(error))
                default:
                    break
                }
            }
        }

        connection.start(queue: .global())

        return connection
    }

    func copyInboundTraffic(from remoteConnection: NWConnection, remoteEndpoint: NWHostEndpoint) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            remoteConnection.receiveMessage { [weak self] data, _, isComplete, error in

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
        let (datagrams, endpoints) = try await read()

        // Ref: https://developer.apple.com/documentation/networkextension/neappproxyudpflow/1406576-readdatagrams
        if datagrams.isEmpty || endpoints.isEmpty {
            throw NEAppProxyFlowError(.aborted)
        }

        for (datagram, endpoint) in zip(datagrams, endpoints) {
            /*
            let host = Network.NWEndpoint.Host(endpoint.hostname)
            let port = Network.NWEndpoint.Port(endpoint.port)!

            let parameters = NWParameters.udp
            parameters.preferNoProxies = true
            parameters.requiredInterface = interface
            parameters.prohibitedInterfaceTypes = [.other]

            let outgoingConnection = Network.NWConnection(to: endpoint, using: .udp)
            NetworkExtension.NWConnection(to: endpoint, using: .udp)*/

            try await send(datagram: datagram, through: remoteConnection)
        }
    }

    /// Reads datagrams from the flow.
    ///
    /// Apple's documentation is very bad here, but it seems each datagram is corresponded with an endpoint at the same position in the array
    /// as mentioned here: https://developer.apple.com/forums/thread/75893
    ///
    private func read() async throws -> (datagrams: [Data], endpoints: [NWEndpoint]) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([Data], [NWEndpoint]), Error>) in
            flow.readDatagrams { datagrams, endpoints, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let datagrams, let endpoints else {
                    continuation.resume(throwing: NEAppProxyFlowError(.aborted))
                    return
                }

                continuation.resume(returning: (datagrams, endpoints))
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
