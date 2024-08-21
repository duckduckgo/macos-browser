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
import os.log

public actor UDSClient {

    public typealias PayloadHandler = (Data) async throws -> Void

    enum ConnectionError: Error {
        case cancelled
        case failure(_ error: Error)
    }

    private var internalConnection: NWConnection?
    private let socketFileURL: URL
    private let receiver: UDSReceiver
    private let queue = DispatchQueue(label: "com.duckduckgo.UDSConnection.queue.\(UUID().uuidString)")
    private let log: OSLog
    private let payloadHandler: PayloadHandler?

    // MARK: - Message completion callbacks

    typealias Callback = (Data?) async -> Void

    private var responseCallbacks = [UUID: Callback]()

    // MARK: - Initializers

    /// This should not be called directly because the socketFileURL needs to comply with some requirements in terms of
    /// maximum length of the path.  Use any public factory method provided below instead.
    ///
    public init(socketFileURL: URL,
                log: OSLog,
                payloadHandler: PayloadHandler? = nil) {

        os_log("UDSClient - Initialized with path: %{public}@", log: log, type: .info, socketFileURL.path)

        self.receiver = UDSReceiver(log: log)
        self.socketFileURL = socketFileURL
        self.log = log
        self.payloadHandler = payloadHandler
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
                await self.statusUpdateHandler(state)
            }
        }

        startReceivingMessages(on: connection)

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

    private func statusUpdateHandler(_ state: NWConnection.State) {
        switch state {
        case .cancelled:
            os_log("UDSClient - Connection cancelled", log: self.log, type: .info)

            self.releaseConnection()
        case .failed(let error):
            os_log("UDSClient - Connection failed with error: %{public}@", log: self.log, type: .error, String(describing: error))

            self.releaseConnection()
        case .ready:
            os_log("UDSClient - Connection ready", log: self.log, type: .info)
        case .waiting(let error):
            os_log("UDSClient - Waiting to connect... %{public}@", log: self.log, type: .info, String(describing: error))
        default:
            os_log("UDSClient - Unexpected state", log: self.log, type: .info)
        }
    }

    private func releaseConnection() {
        internalConnection?.stateUpdateHandler = nil
        internalConnection = nil
    }

    // MARK: - Sending commands

    @discardableResult
    public func send(_ payload: Data) async throws -> Data? {
        let uuid = UUID()
        let message = UDSMessage(uuid: uuid, body: .request(payload))

        return try await send(message)
    }

    private func send(_ message: UDSMessage) async throws -> Data? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in

            Task {
                await send(message) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func send(_ message: UDSMessage, completion: @escaping (Result<Data?, Error>) async -> Void) async {

        do {
            let data = try JSONEncoder().encode(message)
            let lengthData = withUnsafeBytes(of: UDSMessageLength(data.count)) {
                Data($0)
            }
            let payload = lengthData + data
            let connection = try await connection()

            assert(responseCallbacks[message.uuid] == nil)
            responseCallbacks[message.uuid] = { (data: Data?) in
                await completion(.success(data))
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                connection.send(content: payload, completion: .contentProcessed { error in
                    if let error {
                        os_log("UDSClient - Send Error %{public}@", log: self.log, String(describing: error))
                        continuation.resume(throwing: error)
                        return
                    }

                    os_log("UDSClient - Send Success", log: self.log)
                    continuation.resume()
                })
            }
        } catch {
            responseCallbacks.removeValue(forKey: message.uuid)
            await completion(.failure(error))
        }
    }

    /// Starts receiveing messages for a specific connection
    ///
    /// - Parameters:
    ///     - connection: the connection to receive messages for.
    ///
    private func startReceivingMessages(on connection: NWConnection) {

        receiver.startReceivingMessages(on: connection) { [weak self] message in
            guard let self else { return false }

            switch message.body {
            case .request(let payload):
                try await payloadHandler?(payload)
            case .response(let response):
                await handleResponse(uuid: message.uuid, response: response, on: connection)
            }

            return true
        } onError: { [weak self] _ in
            guard let self else { return false }
            await self.closeConnection(connection)
            return false
        }
    }

    private func handleResponse(uuid: UUID, response: UDSMessageResponse, on connection: NWConnection) async {
        guard let callback = responseCallbacks[uuid] else {
            return
        }

        responseCallbacks.removeValue(forKey: uuid)

        switch response {
        case .success(let data):
            await callback(data)
        case .failure:
            await callback(nil)
        }

        return
    }

    private func closeConnection(_ connection: NWConnection) {
        internalConnection?.cancel()
        internalConnection = nil
    }
}
