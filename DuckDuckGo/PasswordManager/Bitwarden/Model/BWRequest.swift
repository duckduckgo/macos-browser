//
//  BWRequest.swift
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

struct BWRequest: Codable {

    static let version = 1

    static func makeHandshakeRequest(with publicKey: String, messageId: String) -> BWRequest {
        let payload = Payload(publicKey: publicKey,
                                      applicationName: Bundle.main.displayName)

        return BWRequest(messageId: messageId,
                                version: version,
                                command: .handshake,
                                payload: payload)
    }

    static func makeEncryptedCommandRequest(encryptedCommand: String, messageId: String) -> BWRequest {
        return BWRequest(messageId: messageId,
                                version: version,
                                encryptedCommand: encryptedCommand)
    }

    let messageId: MessageId?
    let version: Int?
    let command: BWCommand?
    let payload: Payload?
    let encryptedCommand: Base64EncodedString?

    init(messageId: String? = nil,
         version: Int? = nil,
         command: BWCommand? = nil,
         payload: BWRequest.Payload? = nil,
         encryptedCommand: String? = nil) {
        self.messageId = messageId
        self.version = version
        self.command = command
        self.payload = payload
        self.encryptedCommand = encryptedCommand
    }

    struct Payload: Codable {

        init(publicKey: Base64EncodedString? = nil,
             applicationName: String? = nil
        ) {
            self.publicKey = publicKey
            self.applicationName = applicationName
        }

        // Handshake request
        let publicKey: Base64EncodedString?
        let applicationName: String?
    }

    // Need encryption before inserting into encryptedCommand
    struct EncryptedCommand: Codable {

        let command: BWCommand?
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
                Logger.general.fault("BWRequest: Can't encode the message")
                assertionFailure("BWRequest: Can't encode the message")
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
            Logger.general.fault("BWRequest: Can't encode the message")
            assertionFailure("BWRequest: Can't encode the message")
            return nil
        }
        return jsonData
    }

}
