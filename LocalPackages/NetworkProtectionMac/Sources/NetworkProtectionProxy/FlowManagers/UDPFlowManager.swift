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
import os.log

/// A private global actor to handle UDP flows management
///
@globalActor
struct UDPFlowActor {
    actor ActorType { }

    static let shared: ActorType = ActorType()
}

/// Class to handle UDP connections
///
/// This is necessary because as described in the reference comment for this implementation (see ``UDPFlowManager``'s documentation)
/// it's noted that a single UDP flow can have to manage multiple connections.
///
@UDPFlowActor
final class UDPConnectionManager {
    let endpoint: NWEndpoint
    private let connection: NWConnection
    private let onReceive: (_ endpoint: NWEndpoint, _ result: Result<Data, Error>) async -> Void

    init(endpoint: NWHostEndpoint, interface: NWInterface?, onReceive: @UDPFlowActor @escaping (_ endpoint: NWEndpoint, _ result: Result<Data, Error>) async -> Void) {
        let host = Network.NWEndpoint.Host(endpoint.hostname)
        let port = Network.NWEndpoint.Port(endpoint.port)!

        let parameters = NWParameters.udp
        parameters.preferNoProxies = true
        parameters.requiredInterface = interface
        parameters.prohibitedInterfaceTypes = [.other]

        let connection = NWConnection(host: host, port: port, using: parameters)

        self.connection = connection
        self.endpoint = endpoint
        self.onReceive = onReceive
    }

    deinit {
        // Just making extra sure we don't retain anything we don't need to
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    // MARK: - General Operation

    /// Starts the operation of this connection manager
    ///
    /// Can be called multiple times safely.
    ///
    private func start() async throws {
        guard connection.state == .setup else {
            return
        }

        try await connect()

        Task {
            while true {
                do {
                    let datagram = try await receive()
                    await onReceive(endpoint, .success(datagram))
                } catch {
                    connection.cancel()
                    await onReceive(endpoint, .failure(error))
                    break
                }
            }
        }
    }

    // MARK: - Connection Management

    private func connect() async throws {
        try await withCheckedThrowingContinuation { continuation in
            connect { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func connect(completion: @escaping (Result<Void, Error>) -> Void) {
        connection.stateUpdateHandler = { [connection] (state: NWConnection.State) in
            switch state {
            case .ready:
                connection.stateUpdateHandler = nil
                completion(.success(()))
            case .cancelled:
                connection.stateUpdateHandler = nil
                completion(.failure(RemoteConnectionError.cancelled))
            case .failed(let error), .waiting(let error):
                connection.stateUpdateHandler = nil
                completion(.failure(RemoteConnectionError.couldNotEstablishConnection(error)))
            default:
                break
            }
        }

        connection.start(queue: .global())
    }

    // MARK: - Receiving from remote

    private func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receiveMessage { [weak self] data, _, isComplete, error in

                guard self != nil else {
                    continuation.resume(throwing: RemoteConnectionError.cancelled)
                    return
                }

                switch (data, isComplete, error) {
                case (let data?, _, _):
                    continuation.resume(returning: data)
                case (_, true, _):
                    continuation.resume(throwing: RemoteConnectionError.cancelled)
                case (_, _, let error?):
                    continuation.resume(throwing: RemoteConnectionError.unhandledError(error))
                default:
                    continuation.resume(throwing: RemoteConnectionError.cancelled)
                }
            }
        }
    }

    // MARK: - Writing datagrams

    func write(datagram: Data) async throws {
        try await start()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: datagram, completion: .contentProcessed({ error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }))
        }
    }
}

extension UDPConnectionManager: Hashable, Equatable {
    // MARK: - Equatable

    static func == (lhs: UDPConnectionManager, rhs: UDPConnectionManager) -> Bool {
        lhs.endpoint == rhs.endpoint
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(endpoint)
    }
}

/// UDP flow manager class
///
/// There is documentation explaining how to handle TCP flows here:
///     https://developer.apple.com/documentation/networkextension/app_proxy_provider/handling_flow_copying?changes=_8
///
/// Unfortunately there isn't good official documentation showcasing how to implement UDP flow management.
/// The best we could fine are two comments by an Apple engineer that shine some light on how that implementation should be like:
///     https://developer.apple.com/forums/thread/678464?answerId=671531022#671531022
///     https://developer.apple.com/forums/thread/678464?answerId=671892022#671892022
///
/// This class is the result of implementing the description found in that comment.
///
@UDPFlowActor
final class UDPFlowManager {
    private let flow: NEAppProxyUDPFlow
    private var interface: NWInterface?

    private var connectionManagers = [NWEndpoint: UDPConnectionManager]()

    init(flow: NEAppProxyUDPFlow) {
        self.flow = flow
    }

    func start(interface: NWInterface) async throws {
        self.interface = interface
        try await connectAndStartRunLoop()
    }

    private func connectAndStartRunLoop() async throws {
        do {
            try await flow.open(withLocalEndpoint: nil)
            try await startDataCopyLoop()

            flow.closeReadWithError(nil)
            flow.closeWriteWithError(nil)
        } catch {
            flow.closeReadWithError(error)
            flow.closeWriteWithError(error)
        }
    }

    private func startDataCopyLoop() async throws {
        while true {
            try await copyOutoundTraffic()
        }
    }

    func copyInboundTraffic(endpoint: NWEndpoint, result: Result<Data, Error>) async {
        switch result {
        case .success(let data):
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    flow.writeDatagrams([data], sentBy: [endpoint]) { error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }

                        continuation.resume()
                    }
                }
            } catch {
                // Any failure means we close the connection
                connectionManagers.removeValue(forKey: endpoint)
            }
        case .failure:
            // Any failure means we close the connection
            connectionManagers.removeValue(forKey: endpoint)
        }
    }

    func copyOutoundTraffic() async throws {
        let (datagrams, endpoints) = try await read()

        // Ref: https://developer.apple.com/documentation/networkextension/neappproxyudpflow/1406576-readdatagrams
        if datagrams.isEmpty || endpoints.isEmpty {
            throw NEAppProxyFlowError(.aborted)
        }

        for (datagram, endpoint) in zip(datagrams, endpoints) {
            guard let endpoint = endpoint as? NWHostEndpoint else {
                // Not sure what to do about this...
                continue
            }

            let manager = connectionManagers[endpoint] ?? {
                let manager = UDPConnectionManager(endpoint: endpoint, interface: interface, onReceive: copyInboundTraffic)
                connectionManagers[endpoint] = manager
                return manager
            }()

            do {
                try await manager.write(datagram: datagram)
            } catch {
                // Any failure means we close the connection
                connectionManagers.removeValue(forKey: endpoint)
            }
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
