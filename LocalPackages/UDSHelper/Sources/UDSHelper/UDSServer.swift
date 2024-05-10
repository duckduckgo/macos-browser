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
// swiftlint:disable:next enforce_os_log_wrapper
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
public final class UDSServer<Message: Codable> {
    private let listenerQueue = DispatchQueue(label: "com.duckduckgo.UDSServer.listenerQueue")
    private let connectionQueue = DispatchQueue(label: "com.duckduckgo.UDSServer.connectionQueue")

    private var listener: NWListener?
    private var connections = ClientConnections()

    private let receiver: UDSReceiver<Message>

    private let fileManager: FileManager
    private let socketFileURL: URL
    private let log: OSLog

    /// Default initializer
    ///
    /// - Parameters:
    ///     - socketFileDirectory: the directory where we want the socket file to be created.  If you're planning
    ///         to share this socket with other apps in the same app group, this path should be in an app group
    ///         that both apps have access to.
    ///     - socketFileName: the name of the socket file
    ///     - log: the log to use
    ///
    public init(socketFileURL: URL, fileManager: FileManager = .default, log: OSLog) {
        self.fileManager = fileManager
        self.socketFileURL = socketFileURL
        self.log = log
        self.receiver = UDSReceiver<Message>(log: log)

        os_log("UDSServer - Initialized with path: %{public}@", log: log, type: .info, socketFileURL.path)
    }

    public func start(messageHandler: @escaping (Message) -> Void) throws {
        let listener: NWListener

        do {
            let params = NWParameters()
            let shortSocketURL = try fileManager.shortenSocketURL(socketFileURL: socketFileURL, symlinkName: "appgroup")

            os_log("UDSServer - Listening on shortened path: %{public}@", log: log, type: .info, shortSocketURL.path)

            params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
            params.requiredLocalEndpoint = NWEndpoint.unix(path: shortSocketURL.path)
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params)
            self.listener = listener
        } catch {
            os_log("UDSServer - Error creating listener: %{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            throw error
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection, messageHandler: messageHandler)
        }

        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                os_log("UDSServer - Listener is ready", log: log, type: .info)
            case .failed(let error):
                os_log("UDSServer - Listener failed with error: %{public}@", log: log, type: .error, String(describing: error))
                stop()
            case .cancelled:
                os_log("UDSServer - Listener cancelled", log: log, type: .info)
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

    private func handleNewConnection(_ connection: NWConnection, messageHandler: @escaping (Message) -> Void) {
        Task {
            os_log("UDSServer - New connection: %{public}@",
                   log: log,
                   type: .info,
                   String(describing: connection.hashValue))

            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }

                switch state {
                case .ready:
                    os_log("UDSServer - Client connection is ready", log: log, type: .info)
                    self.startReceivingMessages(on: connection, messageHandler: messageHandler)
                case .failed(let error):
                    os_log("UDSServer - Client connection failed with error: %{public}@", log: log, type: .error, String(describing: error))
                    self.closeConnection(connection)
                case .cancelled:
                    os_log("UDSServer - Client connection cancelled", log: log, type: .info)
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
    private func startReceivingMessages(on connection: NWConnection, messageHandler: @escaping (Message) -> Void) {
        receiver.startReceivingMessages(on: connection) { [weak self] event in
            guard let self else { return false }

            switch event {
            case .received(let message):
                messageHandler(message)
            case .error:
                self.closeConnection(connection)
                return false
            }

            return true
        }
    }
}
