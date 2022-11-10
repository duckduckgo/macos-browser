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
import os.log

typealias Base64EncodedString = String
typealias MessageId = String

enum BitwardenCommand: String, Codable {
    case connected // Returned after the proxy process conects to Bitwarden app successfully
    case disconnected // Returned when the conection from the proxy process to Bitwarden is canceled
    case status = "bw-status"
    case handshake = "bw-handshake"
    case credentialRetrieval = "bw-credential-retrieval"
    case credentialCreate = "bw-credential-create"
    case credentialUpdate = "bw-credential-update"
}

struct BitwardenRequest: Codable {

    let messageId: MessageId?
    let version: Int?
    let encryptedCommand: Base64EncodedString

    // Need encryption before inserting into encryptedCommand
    struct EncryptedCommand: Codable {

        let command: BitwardenCommand?
        let payload: Payload?

        struct Payload: Codable {
            internal init(uri: String? = nil,
                          userId: String? = nil,
                          userName: String? = nil,
                          password: String? = nil,
                          name: String? = nil,
                          credentialId: String? = nil) {
                self.uri = uri
                self.userId = userId
                self.userName = userName
                self.password = password
                self.name = name
                self.credentialId = credentialId
            }

            // Credential Retrieval
            let uri: String?

            // Credential Creation
            let userId: String?
            let userName: String?
            let password: String?
            let name: String?

            // Credential Update
            let credentialId: String?
        }

        var data: Data? {
            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(self)
            } catch {
                logOrAssertionFailure("BitwardenMessage: Can't encode the message")
                return nil
            }
            return jsonData
        }

    }

    var data: Data? {
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(self)
        } catch {
            logOrAssertionFailure("BitwardenMessage: Can't encode the message")
            return nil
        }
        return jsonData
    }

}

//TODO: Divide at least to response and request
struct BitwardenMessage: Codable {

    let messageId: MessageId?
    let version: Int?
    let payload: Payload?
    let command: BitwardenCommand?
    let encryptedCommand: Base64EncodedString?
    let encryptedPayload: EncryptedPayload?

    struct PayloadItem: Codable {

        init(error: String? = nil,
             publicKey: Base64EncodedString? = nil,
             applicationName: String? = nil,
             sharedKey: Base64EncodedString? = nil,
             id: String? = nil,
             email: String? = nil,
             status: String? = nil,
             active: Bool? = nil,
             userId: String? = nil,
             credentialId: String? = nil,
             userName: String? = nil,
             password: String? = nil,
             name: String? = nil) {
            self.error = error
            self.publicKey = publicKey
            self.applicationName = applicationName
            self.sharedKey = sharedKey
            self.id = id
            self.email = email
            self.status = status
            self.active = active
            self.userId = userId
            self.credentialId = credentialId
            self.userName = userName
            self.password = password
            self.name = name
        }

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

        // Credential Retrieval
        let userId: String?
        let credentialId: String?
        let userName: String?
        let password: String?
        let name: String?
    }

    struct EncryptedCommand: Codable {

        let command: BitwardenCommand?
        let payload: EncryptedPayload?

        var data: Data? {
            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(self)
            } catch {
                logOrAssertionFailure("BitwardenMessage: Can't encode the message")
                return nil
            }
            return jsonData
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
         command: BitwardenCommand? = nil,
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
            logOrAssertionFailure("Decoding the message failed")
            return nil
        }
    }

    var data: Data? {
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(self)
        } catch {
            logOrAssertionFailure("BitwardenMessage: Can't encode the message")
            return nil
        }
        return jsonData
    }

    static let version = 1

    static func makeHandshakeMessage(with publicKey: String) -> BitwardenMessage {
        let payloadItem = PayloadItem(publicKey: publicKey,
                                      applicationName: Bundle.main.displayName)

        let payload = Payload.item(payloadItem)
        return BitwardenMessage(messageId: generateMessageId(),
                                version: version,
                                command: .handshake,
                                payload: payload)
    }

    static func makeStatusMessage(encryptedCommand: String) -> BitwardenMessage? {
        return BitwardenMessage(messageId: generateMessageId(),
                                version: version,
                                encryptedCommand: encryptedCommand)
    }

    static func makeCredentialRetrievalMessage(encryptedCommand: String, messageId: String) -> BitwardenRequest? {
        return BitwardenRequest(messageId: messageId,
                                version: version,
                                encryptedCommand: encryptedCommand)
    }

    static func makeCredentialCreationMessage(encryptedCommand: String, messageId: String) -> BitwardenRequest? {
        return BitwardenRequest(messageId: messageId,
                                version: version,
                                encryptedCommand: encryptedCommand)
    }

    static func generateMessageId() -> String {
        return UUID().uuidString
    }

}
