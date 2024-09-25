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
import os.log

/// A private global actor to handle UDP flows management
///
@globalActor
struct TCPFlowActor {
    actor ActorType { }

    static let shared: ActorType = ActorType()
}

@TCPFlowActor
enum RemoteConnectionError: CustomNSError {
    case complete
    case cancelled
    case couldNotEstablishConnection(_ error: Error)
    case unhandledError(_ error: Error)

    nonisolated
    var errorUserInfo: [String: Any] {
        switch self {
        case .complete,
                .cancelled:
            return [:]
        case .couldNotEstablishConnection(let error),
                .unhandledError(let error):
            return [NSUnderlyingErrorKey: error as NSError]

        }
    }
}

final class TCPFlowManager {
    private let flow: NEAppProxyTCPFlow
    private var connectionTask: Task<Void, Error>?
    private var connection: NWConnection?
    private let logger: Logger

    init(flow: NEAppProxyTCPFlow, logger: Logger) {
        self.flow = flow
        self.logger = logger
    }

    deinit {
        // Just making extra sure we don't have any unexpected retain cycle
        connection?.stateUpdateHandler = nil
        connection?.cancel()
    }

    func start(interface: NWInterface) async throws {
        guard let remoteEndpoint = flow.remoteEndpoint as? NWHostEndpoint else {
            return
        }

        try await connectAndStartRunLoop(remoteEndpoint: remoteEndpoint, interface: interface)
    }

    private func connectAndStartRunLoop(remoteEndpoint: NWHostEndpoint, interface: NWInterface) async throws {
        let remoteConnection = try await connect(to: remoteEndpoint, interface: interface)
        try await flow.open(withLocalEndpoint: nil)

        do {
            try await startDataCopyLoop(for: remoteConnection)

            logger.log("Stopping proxy connection to \(remoteEndpoint, privacy: .public)")
            remoteConnection.cancel()
            flow.closeReadWithError(nil)
            flow.closeWriteWithError(nil)
        } catch {
            logger.log("Stopping proxy connection to \(remoteEndpoint, privacy: .public) with error \(String(reflecting: error), privacy: .public)")

            remoteConnection.cancel()
            flow.closeReadWithError(error)
            flow.closeWriteWithError(error)
        }
    }

    func connect(to remoteEndpoint: NWHostEndpoint, interface: NWInterface) async throws -> NWConnection {
        try await withCheckedThrowingContinuation { continuation in
            connect(to: remoteEndpoint, interface: interface) { result in
                switch result {
                case .success(let connection):
                    continuation.resume(returning: connection)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func connect(to remoteEndpoint: NWHostEndpoint, interface: NWInterface, completion: @escaping @TCPFlowActor (Result<NWConnection, Error>) -> Void) {
        let host = Network.NWEndpoint.Host(remoteEndpoint.hostname)
        let port = Network.NWEndpoint.Port(remoteEndpoint.port)!

        let parameters = NWParameters.tcp
        parameters.preferNoProxies = true
        parameters.requiredInterface = interface
        parameters.prohibitedInterfaceTypes = [.other]

        let connection = NWConnection(host: host, port: port, using: parameters)
        self.connection = connection

        connection.stateUpdateHandler = { (state: NWConnection.State) in
            Task { @TCPFlowActor in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    completion(.success(connection))
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
        }

        connection.start(queue: .global())
    }

    private func startDataCopyLoop(for remoteConnection: NWConnection) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                while true {
                    guard let self else {
                        throw RemoteConnectionError.cancelled
                    }

                    try Task.checkCancellation()
                    try await self.copyOutboundTraffic(to: remoteConnection)
                }
            }

            group.addTask { [weak self] in
                while true {
                    guard let self else {
                        throw RemoteConnectionError.cancelled
                    }

                    try Task.checkCancellation()
                    try await self.copyInboundTraffic(from: remoteConnection)
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

    @MainActor
    func closeFlow(remoteConnection: NWConnection, error: Error?) {
        remoteConnection.forceCancel()
        flow.closeReadWithError(error)
        flow.closeWriteWithError(error)
    }

    static let maxReceiveSize: Int = Int(Measurement(value: 2, unit: UnitInformationStorage.megabytes).converted(to: .bytes).value)

    func copyInboundTraffic(from remoteConnection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @TCPFlowActor in
                remoteConnection.receive(minimumIncompleteLength: 1,
                                         maximumLength: Self.maxReceiveSize) { [weak flow] (data, _, isComplete, error) in
                    guard let flow else {
                        continuation.resume(throwing: RemoteConnectionError.cancelled)
                        return
                    }

                    switch (data, isComplete, error) {
                    case (.some(let data), _, _) where !data.isEmpty:
                        flow.write(data) { writeError in
                            if let writeError {
                                continuation.resume(throwing: writeError)
                                remoteConnection.cancel()
                            } else {
                                continuation.resume()
                            }
                        }
                    case (_, isComplete, _) where isComplete == true:
                        continuation.resume(throwing: RemoteConnectionError.complete)
                        remoteConnection.cancel()
                    case (_, _, .some(let error)):
                        continuation.resume(throwing: RemoteConnectionError.unhandledError(error))
                        remoteConnection.cancel()
                    default:
                        continuation.resume(throwing: RemoteConnectionError.complete)
                        remoteConnection.cancel()
                    }
                }
            }
        }
    }

    func copyOutboundTraffic(to remoteConnection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @TCPFlowActor in
                flow.readData { data, error in
                    switch (data, error) {
                    case (.some(let data), _) where !data.isEmpty:
                        remoteConnection.send(content: data, completion: .contentProcessed({ error in
                            if let error {
                                continuation.resume(throwing: error)
                                remoteConnection.cancel()
                                return
                            }

                            continuation.resume()
                        }))
                    case (_, .some(let error)):
                        continuation.resume(throwing: error)
                        remoteConnection.cancel()
                    default:
                        continuation.resume(throwing: RemoteConnectionError.complete)
                        remoteConnection.cancel()
                    }
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
