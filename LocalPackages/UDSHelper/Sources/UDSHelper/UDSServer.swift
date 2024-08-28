//
//  UDSServer.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Network
import os.log

/// Convenience Hashable support for `NWConnection`, so we can use `Set<NWConnection>`
///
extension NWConnection: Hashable {
    public static func == (lhs: NWConnection, rhs: NWConnection) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// An actor to manage client connections in a thread-safe manner.
///
private actor ClientConnections {
    var connections = Set<NWConnection>()

    func forEach(perform closure: (NWConnection) -> Void) {
        // Copy the set for looping so that operations that modify the set
        // won't cause trouble.
        let connections = connections

        for connection in connections {
            closure(connection)
        }
    }

    func insert(_ connection: NWConnection) {
        connections.insert(connection)
    }

    func remove(_ connection: NWConnection) {
        connections.remove(connection)
    }

    func removeAll() {
        connections = Set<NWConnection>()
    }
}

/// Unix Domain Socket server
///
public final class UDSServer {
    private let listenerQueue = DispatchQueue(label: "com.duckduckgo.UDSServer.listenerQueue")
    private let connectionQueue = DispatchQueue(label: "com.duckduckgo.UDSServer.connectionQueue")

    private var listener: NWListener?
    private var connections = ClientConnections()

    private let receiver: UDSReceiver

    private let fileManager: FileManager
    private let socketFileURL: URL

    /// Default initializer
    ///
    /// - Parameters:
    ///     - socketFileDirectory: the directory where we want the socket file to be created.  If you're planning
    ///         to share this socket with other apps in the same app group, this path should be in an app group
    ///         that both apps have access to.
    ///     - socketFileName: the name of the socket file
    ///
    public init(socketFileURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.socketFileURL = socketFileURL
        self.receiver = UDSReceiver()

        do {
            try fileManager.removeItem(at: socketFileURL)
        } catch {
            print(error)
        }

        Logger.udsHelper.info("UDSServer - Initialized with path: \(socketFileURL.path, privacy: .public)")
    }

    public func start(messageHandler: @escaping (Data) async throws -> Data?) throws {
        let listener: NWListener

        do {
            let params = NWParameters()
            params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
            params.requiredLocalEndpoint = NWEndpoint.unix(path: socketFileURL.path)
            params.allowLocalEndpointReuse = true
            // IMPORTANT: I'm leaving the following line commented because I want to document
            // that enabling it seems to break the UDS listener completely.
            // params.acceptLocalOnly = true

            listener = try NWListener(using: params)
            self.listener = listener
        } catch {
            Logger.udsHelper.error("UDSServer - Error creating listener: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection, messageHandler: messageHandler)
        }

        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                Logger.udsHelper.info("UDSServer - Listener is ready")
            case .failed(let error):
                Logger.udsHelper.error("UDSServer - Listener failed with error: \(error.localizedDescription, privacy: .public)")
                stop()
            case .cancelled:
                Logger.udsHelper.info("UDSServer - Listener cancelled")
            default:
                break
            }
        }

        listener.start(queue: listenerQueue)
    }

    func stop() {
        guard let listener else {
            return
        }

        listener.cancel()
        listener.newConnectionHandler = nil
        listener.stateUpdateHandler = nil

        Task {
            await stopConnections()
        }
    }

    private func stopConnections() async {
        await connections.forEach { connection in
            connection.cancel()
        }

        await connections.removeAll()
    }

    private func handleNewConnection(_ connection: NWConnection, messageHandler: @escaping (Data) async throws -> Data?) {
        Task {
            Logger.udsHelper.info("UDSServer - New connection: \(String(describing: connection.hashValue), privacy: .public)")

            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }

                switch state {
                case .ready:
                    Logger.udsHelper.info("UDSServer - Client connection is ready")
                    self.startReceivingMessages(on: connection, messageHandler: messageHandler)
                case .failed(let error):
                    Logger.udsHelper.error("UDSServer - Client connection failed with error: \(error.localizedDescription, privacy: .public)")
                    self.closeConnection(connection)
                case .cancelled:
                    Logger.udsHelper.info("UDSServer - Client connection cancelled")
                default:
                    break
                }
            }

            await connections.insert(connection)
            connection.start(queue: connectionQueue)
        }
    }

    private func closeAllConnections() {
        Task {
            await connections.forEach { connection in
                connection.cancel()
            }

            await connections.removeAll()
        }
    }

    private func closeConnection(_ connection: NWConnection) {
        Task {
            await self.connections.remove(connection)
            connection.cancel()
        }
    }

    // - MARK: Data reception logic

    private enum ReadError: Error {
        case notEnoughData(expected: Int, received: Int)
        case connectionError(_ error: Error)
        case connectionClosed
    }

    /// Starts receiveing messages for a specific connection
    ///
    /// - Parameters:
    ///     - connection: the connection to receive messages for.
    ///
    private func startReceivingMessages(on connection: NWConnection, messageHandler: @escaping (Data) async throws -> Data?) {

        receiver.startReceivingMessages(on: connection) { [weak self] message in
            guard let self else { return false }

            switch message.body {
            case .request(let data):
                let responsePayload = try await messageHandler(data)
                let responseMessage = message.successResponse(withPayload: responsePayload)
                try await self.send(responseMessage, connection: connection)
            case .response:
                // We still don't fully support server to client messages.  This is the location where we'd
                // add the handling for that.
                //
                // This will be useful if we, for example, want to move VPN status observation to UDS.
                //
                break
            }

            return true
        } onError: { [weak self] _ in
            guard let self else { return false }
            self.closeConnection(connection)
            return false
        }
    }

    private func send(_ message: UDSMessage, connection: NWConnection) async throws {

        let data = try JSONEncoder().encode(message)
        let lengthData = withUnsafeBytes(of: UDSMessageLength(data.count)) {
            Data($0)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error {
                    Logger.udsHelper.error("UDSServer - Send Error \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                    return
                }

                Logger.udsHelper.info("UDSServer - Send Success")
                continuation.resume()
            })
        }
    }
}
