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

actor UDSConnection<Message: Codable> {
    private var internalConnection: NWConnection?
    private let endpoint: NWEndpoint
    private let parameters: NWParameters
    private let messageHandler: (Message) -> Void
    private let receiver: UDSReceiver<Message>

    init(to endpoint: NWEndpoint, using parameters: NWParameters, log: OSLog, messageHandler: @escaping (Message) -> Void) {
        self.endpoint = endpoint
        self.parameters = parameters
        self.messageHandler = messageHandler
        self.receiver = UDSReceiver<Message>(log: log)
    }

    private var connection: NWConnection {
        internalConnection ?? { [messageHandler] in
            let newConnection = NWConnection(to: endpoint, using: parameters)

            startReceivingMessages(on: newConnection, messageHandler: messageHandler)

            self.internalConnection = newConnection
            return newConnection
        }()
    }

    func send(content: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: content, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            })
        }
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

final class UDSClient<Message: Codable> {
    private let queue = DispatchQueue(label: "com.duckduckgo.UDSClient.queue")

    private let connection: UDSConnection<Message>

    private let log: OSLog

    init(path: String, log: OSLog, messageHandler: @escaping (Message) -> Void) {
        let socketFile = URL(fileURLWithPath: path)

        self.log = log
        self.connection = UDSConnection(to: .unix(path: socketFile.path),
                                        using: NWParameters(),
                                        log: log,
                                        messageHandler: messageHandler)
    }

    func send(message: Message) async throws {
        let data = try JSONEncoder().encode(message)
        let lengthData = withUnsafeBytes(of: UDSMessageLength(data.count)) {
            Data($0)
        }

        try await connection.send(content: lengthData + data)
    }

    enum ReadError: Error {
        case connectionClosed
    }
}
