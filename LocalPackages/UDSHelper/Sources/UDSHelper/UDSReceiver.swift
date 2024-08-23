//
//  UDSReceiver.swift
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

typealias UDSMessageLength = UInt16

struct UDSReceiver {

    /// The return value allows the callback handler to continue receiving messages (if it returns `true`)
    /// or stop receiving messages (when it returns `false`).
    ///
    typealias MessageHandler = (UDSMessage) async throws -> Bool

    enum ReadError: Error {
        case notEnoughData(expected: Int, received: Int)
        case connectionError(_ error: Error)
        case connectionClosed
    }

    /// Starts receiveing messages for a specific connection
    ///
    /// - Parameters:
    ///     - connection: the connection to receive messages for.
    ///     - messageHandler: the callback for important events.
    ///
    func startReceivingMessages(on connection: NWConnection, messageHandler: @escaping MessageHandler, onError errorHandler: @escaping (Error) async -> Bool) {
        Task {
            await runReceiveMessageLoop(on: connection, messageHandler: messageHandler, onError: errorHandler)
        }
    }

    private func runReceiveMessageLoop(on connection: NWConnection, messageHandler: @escaping MessageHandler, onError errorHandler: @escaping (Error) async -> Bool) async {

        while true {
            do {
                let length = try await receiveMessageLength(on: connection)
                let message = try await receiveEncodedObjectData(ofLength: length, on: connection)

                guard try await messageHandler(message) else {
                    return
                }
            } catch {
                switch error {
                case ReadError.notEnoughData(let expected, let received):
                    Logger.udsHelper.error("UDSServer - Connection closing due to error: Not enough data (expected: \(String(describing: expected), privacy: .public), received:  \(String(describing: received), privacy: .public)")

                    guard await errorHandler(error) else {
                        return
                    }
                case ReadError.connectionError(let error):
                    Logger.udsHelper.error("UDSServer - Connection closing due to a connection error: \(error.localizedDescription, privacy: .public)")

                    guard await errorHandler(error) else {
                        return
                    }
                case ReadError.connectionClosed:
                    Logger.udsHelper.info("UDSServer - Connection closing: End of file reached")

                    guard await errorHandler(error) else {
                        return
                    }
                default:
                    Logger.udsHelper.error("UDSServer - Connection closing due to error: \(error.localizedDescription, privacy: .public)")

                    guard await errorHandler(error) else {
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
    private func receiveEncodedObjectData(ofLength length: UDSMessageLength, on connection: NWConnection) async throws -> UDSMessage {
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

    private func decodeMessage(from data: Data) throws -> UDSMessage {
        try JSONDecoder().decode(UDSMessage.self, from: data)
    }
}
