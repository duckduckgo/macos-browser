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
        let endpoint = NWEndpoint.unix(path: socketFileURL.path)
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { state in
            Task {
                try await self.statusUpdateHandler(state)
            }
        }

        internalConnection = connection
        connection.start(queue: queue)

        while connection.state != .ready {
            switch connection.state {
            case .cancelled:
                throw ConnectionError.cancelled
            case .failed(let error):
                throw ConnectionError.failure(error)
            default:
                try await Task.sleep(nanoseconds: 200 * MSEC_PER_SEC)
            }
        }

        return connection
    }

    private func statusUpdateHandler(_ state: NWConnection.State) async throws {
        switch state {
        case .cancelled:
            os_log("UDSClient - Connection cancelled", log: self.log, type: .info)

            self.releaseConnection()
            throw ConnectionError.cancelled
        case .failed(let error):
            os_log("UDSClient - Connection failed with error: %{public}@", log: self.log, type: .error, String(describing: error))

            self.releaseConnection()
            throw ConnectionError.failure(error)
        case .ready:
            os_log("UDSClient - Connection ready", log: self.log, type: .info)
        case .waiting(let error):
            os_log("UDSClient - Waiting to connect... %{public}@", log: self.log, type: .info, String(describing: error))
        default:
            os_log("UDSClient - Unexpected state", log: self.log, type: .info)
            break
        }
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
