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

typealias UDSMessageLength = UInt16

struct UDSReceiver<Message: Codable> {

    /// The return value allows the callback handler to continue receiving messages (if it returns `true`)
    /// or stop receiving messages (when it returns `false`).
    ///
    typealias EventHandler = (Event) async -> Bool

    private enum ReadError: Error {
        case notEnoughData(expected: Int, received: Int)
        case connectionError(_ error: Error)
        case connectionClosed
    }

    enum Event {
        case received(_ message: Message)
        case error(_ error: Error)
    }

    private let log: OSLog

    init(log: OSLog) {
        self.log = log
    }

    /// Starts receiveing messages for a specific connection
    ///
    /// - Parameters:
    ///     - connection: the connection to receive messages for.
    ///     - messageHandler: the callback for important events.
    ///
    func startReceivingMessages(on connection: NWConnection, eventHandler: @escaping EventHandler) {
        Task {
            await runReceiveMessageLoop(on: connection, eventHandler: eventHandler)
        }
    }

    private func runReceiveMessageLoop(on connection: NWConnection, eventHandler: @escaping EventHandler) async {
        while true {
            do {
                let length = try await receiveMessageLength(on: connection)
                let message = try await receiveEncodedObjectData(ofLength: length, on: connection)

                guard await eventHandler(.received(message)) else {
                    return
                }
            } catch {
                switch error {
                case ReadError.notEnoughData(let expected, let received):
                    os_log("UDSServer - Connection closing due to error: Not enough data (expected: %{public}@, received:  %{public}@",
                           log: log,
                           type: .error,
                           String(describing: expected),
                           String(describing: received))

                    guard await eventHandler(.error(error)) else {
                        return
                    }
                case ReadError.connectionError(let error):
                    os_log("UDSServer - Connection closing due to a connection error: %{public}@",
                           log: log,
                           type: .error,
                           String(describing: error))

                    guard await eventHandler(.error(error)) else {
                        return
                    }
                case ReadError.connectionClosed:
                    os_log("UDSServer - Connection closing: End of file reached",
                           log: log,
                           type: .info)

                    guard await eventHandler(.error(error)) else {
                        return
                    }
                default:
                    os_log("UDSServer - Connection closing due to error: %{public}@",
                           log: log,
                           type: .error,
                           String(describing: error))

                    guard await eventHandler(.error(error)) else {
                        return
                    }
                }
            }
        }
    }

    /// Receives the length value for the next message in the data stream.
    ///
    /// - Parameters:
    ///     - connection: the connection through which we're receveing messages
    ///
    /// - Returns: the length of the next message
    ///
    private func receiveMessageLength(on connection: NWConnection) async throws -> UDSMessageLength {
        try await withCheckedThrowingContinuation { continuation in
            let messageLengthMemorySize = MemoryLayout<UDSMessageLength>.size

            connection.receive(minimumIncompleteLength: messageLengthMemorySize, maximumLength: messageLengthMemorySize) { (data, _, isComplete, error) in

                if let data = data {
                    guard data.count == messageLengthMemorySize else {
                        continuation.resume(throwing: ReadError.notEnoughData(expected: messageLengthMemorySize, received: data.count))
                        return
                    }

                    let length = data.withUnsafeBytes { $0.load(as: UDSMessageLength.self) }
                    continuation.resume(returning: length)
                }

                if let error {
                    continuation.resume(throwing: ReadError.connectionError(error))
                    return
                }

                guard !isComplete else {
                    continuation.resume(throwing: ReadError.connectionClosed)
                    return
                }
            }
        }
    }

    /// Decodes an incoming message.
    ///
    /// - Parameters:
    ///     - length: the length of the data that represents the next message.
    ///     - connection: the connection through which we're receiving the message.
    ///
    /// - Returns: a message on success.
    ///
    private func receiveEncodedObjectData(ofLength length: UDSMessageLength, on connection: NWConnection) async throws -> Message {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, _, isComplete, error) in
                if let data = data {
                    guard data.count == length else {
                        continuation.resume(throwing: ReadError.notEnoughData(expected: Int(length), received: data.count))
                        return
                    }

                    do {
                        let message = try self.decodeMessage(from: data)
                        continuation.resume(returning: message)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                if let error {
                    continuation.resume(throwing: ReadError.connectionError(error))
                    return
                }

                guard !isComplete else {
                    continuation.resume(throwing: ReadError.connectionClosed)
                    return
                }
            }
        }
    }

    private func decodeMessage(from data: Data) throws -> Message {
        try JSONDecoder().decode(Message.self, from: data)
    }
}
