//
//  BWResponse.swift
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

struct BWResponse: Codable {

    let messageId: MessageId?
    let version: Int?
    let payload: Payload?
    let command: BWCommand?
    let encryptedCommand: Base64EncodedString?
    let encryptedPayload: EncryptedPayload?

    struct PayloadItem: Codable {
        let error: String?

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

    init?(from messageData: Data) {
        do {
            self = try JSONDecoder().decode(BWResponse.self, from: messageData)
        } catch {
            Logger.general.fault("Decoding the message failed")
            assertionFailure("Decoding the message failed")
            return nil
        }
    }

}
