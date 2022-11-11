//
//  BitwardenError.swift
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

enum BitwardenError: Error {

    // Blocking errors (further communication blocked)
    case handshakeFailed
    case decryptionOfSharedKeyFailed
    case parsingFailed
    case statusParsingFailed

    // Non-blocking errors
    case decryptionOfDataFailed
    case noActiveVault
    case storingOfTheSharedKeyFailed
    case sendingOfStatusMessageFailed
    case injectingOfSharedKeyFailed
    case runningOfProxyProcessFailed
    case credentialCreationFailed
    case credentialUpdateFailed
    case credentialRetrievalFailed

    // Errors received from Bitwarden
    case bitwardenCannotDecrypt
    case bitwardenRespondedWithError

    var text: String {
        switch self {
        case .handshakeFailed: return "Handshake failed"
        case .decryptionOfSharedKeyFailed: return "Decryption of shared key failed"
        case .parsingFailed: return "Parsing failed"
        case .statusParsingFailed: return "Status parsing failed"
        case .decryptionOfDataFailed: return "Decryption of data failed"
        case .noActiveVault: return "No active vault"
        case .storingOfTheSharedKeyFailed: return "Storing of the shared key Failed"
        case .sendingOfStatusMessageFailed: return "Sending of the status message failed"
        case .injectingOfSharedKeyFailed: return "Injecting of the shared key failed"
        case .runningOfProxyProcessFailed: return "Running of proxy process failed"
        case .bitwardenCannotDecrypt: return "Bitwarden cannot decrypt the message"
        case .bitwardenRespondedWithError: return "Bitwarden responded with error"
        case .credentialCreationFailed: return "Credential creation in Bitwarden failed"
        case .credentialUpdateFailed: return "Credential update in Bitwarden failed"
        case .credentialRetrievalFailed: return "Credential retrieval failed"
        }
    }

}
