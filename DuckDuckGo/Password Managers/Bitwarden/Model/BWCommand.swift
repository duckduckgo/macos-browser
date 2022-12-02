//
//  BWCommand.swift
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

enum BWCommand: String, Codable {

    // Received after the proxy process conects to Bitwarden app successfully
    case connected

    // Received when the conection from the proxy process to Bitwarden is canceled
    case disconnected

    //  Handshake message that initiates communication. Sent during the onboarding only
    case handshake = "bw-handshake"

    // Status message
    case status = "bw-status"

    // Credentials
    case credentialRetrieval = "bw-credential-retrieval"
    case credentialCreate = "bw-credential-create"
    case credentialUpdate = "bw-credential-update"

}
