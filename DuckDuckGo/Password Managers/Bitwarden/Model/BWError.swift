//
//  BWError.swift
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

enum BWError: Error {

    // Blocking errors (further communication not possible)
    case handshakeFailed
    case runningOfProxyProcessFailed
    case decryptionOfSharedKeyFailed

    case parsingFailed
    case statusParsingFailed
    case decryptionOfDataFailed
    case noActiveVault
    case storingOfTheSharedKeyFailed
    case sendingOfMessageFailed
    case sharedKeyInjectionFailed

    case credentialCreationFailed
    case credentialUpdateFailed
    case credentialRetrievalFailed

    // Errors received from Bitwarden
    case bitwardenCannotDecrypt
    case bitwardenRespondedWithError

}
