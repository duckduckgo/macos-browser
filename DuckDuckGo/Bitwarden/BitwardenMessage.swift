//
//  BitwardenMessage.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

//TODO Divide at least to response and request
struct BitwardenMessage: Codable {

    let messageId: String?
    let version: Int?
    let payload: Payload?
    let command: String?
    let encryptedCommand: EncryptedCommand?

    struct Payload: Codable {

        let error: String?
        let publicKey: String? // base64 encoded
        let status: String?
        let sharedKey: String? // base64 encoded

    }

    struct EncryptedCommand: Codable {

        let command: String?
        let payload: EncryptedPayload?

    }

    enum EncryptedPayload: Codable {
        case array([String])
        case string(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            do {
                self = try .array(container.decode(Array.self))
            } catch DecodingError.typeMismatch {
                do {
                    self = try .string(container.decode(String.self))
                } catch DecodingError.typeMismatch {
                    throw DecodingError.typeMismatch(EncryptedPayload.self,
                                                     DecodingError.Context(codingPath: decoder.codingPath,
                                                                           debugDescription: "Encoded payload not of an expected type"))
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .array(let array):
                try container.encode(array)
            case .string(let string):
                try container.encode(string)
            }
        }
    }

    init(messageId: String? = nil,
         version: Int? = nil,
         command: String? = nil,
         payload: BitwardenMessage.Payload? = nil,
         encryptedCommand: EncryptedCommand? = nil) {
        self.messageId = messageId
        self.version = version
        self.command = command
        self.payload = payload
        self.encryptedCommand = encryptedCommand
    }

    init?(from messageData: Data) {
        do {
            self = try JSONDecoder().decode(BitwardenMessage.self, from: messageData)
        } catch {
            assertionFailure("Decoding the message failed \(error)")
            return nil
        }
    }

    var data: Data? {
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(self)
        } catch {
            assertionFailure("BitwardenMessage: Can't encode the message \(error)")
            return nil
        }
        return jsonData
    }

    static let version = 1
    static let handshakeCommand = "bw-handshake"

    static func makeHandshakeMessage(with publicKey: String) -> BitwardenMessage {
        let payload = Payload(error: nil,
                              publicKey: publicKey,
                              status: nil,
                              sharedKey: nil)
        return BitwardenMessage(messageId: generateMessageId(),
                                version: version,
                                command: handshakeCommand,
                                payload: payload)
    }

    static func makeStatusMessage() -> BitwardenMessage {
        let encryptedCommand = EncryptedCommand(command: "bw-status", payload: nil)
        return BitwardenMessage(messageId: generateMessageId(),
                                version: version,
                                encryptedCommand: encryptedCommand)
    }

    static func generateMessageId() -> String {
        return UUID().uuidString
    }

}
