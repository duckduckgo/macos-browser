//
//  File.swift
//  
//
//  Created by ddg on 11/18/23.
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
    private let endpoint: NWEndpoint
    private let parameters: NWParameters
    private let receiver: UDSReceiver<Incoming>
    private let queue = DispatchQueue(label: "com.duckduckgo.UDSConnection.queue.\(UUID().uuidString)")
    private let log: OSLog

    public init(socketFileURL: URL, log: OSLog) {
        let shortSocketURL = try fileManager.shortenSocketURL(socketFileURL: socketFileURL, symlinkName: "appgroup")

        endpoint = .unix(path: shortSocketURL)
        parameters = NWParameters()
        self.receiver = UDSReceiver<Incoming>(log: log)
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
        let connection = NWConnection(to: endpoint, using: parameters)
        internalConnection = connection

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in

                connection.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }

                    Task {
                        switch state {
                        case .cancelled:
                            await self.releaseConnection()
                            continuation.resume(throwing: ConnectionError.cancelled)
                        case .failed(let error):
                            await self.releaseConnection()
                            continuation.resume(throwing: ConnectionError.failure(error))
                        case .ready:
                            await self.retainConnection(connection)
                            continuation.resume(returning: connection)
                        default:
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
                    os_log("UDSConnection - Send Error %{public}@", String(describing: error))
                    continuation.resume(throwing: error)
                    return
                }

                os_log("UDSConnection - Send Success")
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
