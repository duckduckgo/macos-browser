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

typealias Base64EncodedString = String

//TODO: Divide at least to response and request
struct BitwardenMessage: Codable {

    let messageId: String?
    let version: Int?
    let payload: Payload?
    let command: String?
    let encryptedCommand: Base64EncodedString?
    let encryptedPayload: EncryptedPayload?

    struct PayloadItem: Codable {

        let error: String?

        // Handshake request
        let publicKey: Base64EncodedString?
        let applicationName: String?

        // Handshake responce
        let sharedKey: Base64EncodedString?

        // Status
        let id: String?
        let email: String?
        let status: String?
        let active: Bool?

    }

    struct EncryptedCommand: Codable {

        let command: String?
        let payload: EncryptedPayload?

        var data: Data? {
            guard let commandData = try? JSONEncoder().encode(self) else {
                assertionFailure("JSON encoding failed")
                return nil
            }
            return commandData
        }

    }

    enum Payload: Codable {
        case array([PayloadItem])
        case item(PayloadItem)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            do {
                self = try .array(container.decode(Array<PayloadItem>.self))
            } catch DecodingError.typeMismatch {
                do {
                    self = try .item(container.decode(PayloadItem.self))
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
            case .item(let item):
                try container.encode(item)
            }
        }
    }

    struct EncryptedPayload: Codable {

        let encryptedString: String?
        let encryptionType: Int?
        let data: String?
        let iv: String?
        let mac: String?

    }

    init(messageId: String? = nil,
         version: Int? = nil,
         command: String? = nil,
         payload: BitwardenMessage.Payload? = nil,
         encryptedCommand: String? = nil,
         encryptedPayload: EncryptedPayload? = nil) {
        self.messageId = messageId
        self.version = version
        self.command = command
        self.payload = payload
        self.encryptedCommand = encryptedCommand
        self.encryptedPayload = encryptedPayload
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
        let payloadItem = PayloadItem(error: nil,
                                      publicKey: publicKey,
                                      applicationName: Bundle.main.displayName,
                                      sharedKey: nil,
                                      id: nil,
                                      email: nil,
                                      status: nil,
                                      active: nil)

        let payload = Payload.item(payloadItem)
        return BitwardenMessage(messageId: generateMessageId(),
                                version: version,
                                command: handshakeCommand,
                                payload: payload)
    }

    static func makeStatusMessage(encryptedCommand: String) -> BitwardenMessage? {
        return BitwardenMessage(messageId: generateMessageId(),
                                version: version,
                                encryptedCommand: encryptedCommand)
    }

    static func generateMessageId() -> String {
        return UUID().uuidString
    }

}
