//
//  UDSClient.swift
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

public actor UDSClient<Incoming: Codable, Outgoing: Codable> {

    enum ConnectionError: Error {
        case cancelled
        case failure(_ error: Error)
    }

    private var internalConnection: NWConnection?
    private let socketFileURL: URL
    private let receiver: UDSReceiver<Incoming>
    private let urlShortener: UDSURLShortening
    private let queue = DispatchQueue(label: "com.duckduckgo.UDSConnection.queue.\(UUID().uuidString)")
    private let log: OSLog

    /// This should not be called directly because the socketFileURL needs to comply with some requirements in terms of
    /// maximum length of the path.  Use any public factory method provided below instead.
    ///
    public init(socketFileURL: URL,
                urlShortener: UDSURLShortening = UDSURLShortener(),
                log: OSLog) {

        os_log("UDSClient - Initialized with path: %{public}@", log: log, type: .info, socketFileURL.path)

        self.receiver = UDSReceiver<Incoming>(log: log)
        self.socketFileURL = socketFileURL
        self.urlShortener = urlShortener
        self.log = log
    }

    // MARK: - Connection Management

    private func connection() async throws -> NWConnection {
        guard let internalConnection,
              internalConnection.state == .ready else {

            return try await connect()
        }

        return internalConnection
    }

    /// Establishes a new connection
    ///
    private func connect() async throws -> NWConnection {
        /*let shortSocketURL: URL

        do {
            shortSocketURL = try urlShortener.shorten(socketFileURL, symlinkName: "appgroup")
        } catch {
            os_log("UDSClient - Error creating short path for socket: %{public}@",
                   log: log,
                   type: .error,
                   String(describing: error))
            throw error
        }*/

        //os_log("UDSClient - Connecting to shortened path: %{public}@", log: log, type: .info, shortSocketURL.path)

        let endpoint = NWEndpoint.unix(path: socketFileURL.path)
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)
        internalConnection = connection

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                connection.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }

                    Task {
                        switch state {
                        case .cancelled:
                            os_log("UDSClient - Connection cancelled", log: self.log, type: .info)

                            await self.releaseConnection()
                            continuation.resume(throwing: ConnectionError.cancelled)
                        case .failed(let error):
                            os_log("UDSClient - Connection failed with error: %{public}@", log: self.log, type: .error, String(describing: error))

                            await self.releaseConnection()
                            continuation.resume(throwing: ConnectionError.failure(error))
                        case .ready:
                            os_log("UDSClient - Connection ready", log: self.log, type: .info)

                            await self.retainConnection(connection)
                            continuation.resume(returning: connection)
                        case .waiting(let error):
                            os_log("UDSClient - Waiting to connect... %{public}@", log: self.log, type: .info, String(describing: error))
                        default:
                            os_log("UDSClient - Unexpected state", log: self.log, type: .info)

                            break
                        }
                    }
                }

                connection.start(queue: queue)
            }
        } onCancel: {
            connection.cancel()
        }
    }

    private func retainConnection(_ connection: NWConnection) {
        internalConnection = connection
    }

    private func releaseConnection() {
        internalConnection?.stateUpdateHandler = nil
        internalConnection = nil
    }

    // MARK: - Sending commands

    public func send(_ command: Outgoing) async throws {
        let data = try JSONEncoder().encode(command)
        let lengthData = withUnsafeBytes(of: UDSMessageLength(data.count)) {
            Data($0)
        }

        let connection = try await connection()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error {
                    os_log("UDSClient - Send Error %{public}@", log: self.log, String(describing: error))
                    continuation.resume(throwing: error)
                    return
                }

                os_log("UDSClient - Send Success", log: self.log)
                continuation.resume()
            })
        }
    }

    /// Starts receiveing messages for a specific connection
    ///
    /// - Parameters:
    ///     - connection: the connection to receive messages for.
    ///
    private func startReceivingMessages(on connection: NWConnection, messageHandler: @escaping (Incoming) -> Void) {

        receiver.startReceivingMessages(on: connection) { [weak self] event in
            guard let self else { return false }

            switch event {
            case .received(let message):
                messageHandler(message)
            case .error:
                await self.closeConnection(connection)
                return false
            }

            return true
        }
    }

    private func closeConnection(_ connection: NWConnection) {
        internalConnection?.cancel()
        internalConnection = nil
    }
}
