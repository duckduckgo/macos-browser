//
//  BWStatus.swift
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

enum BWStatus: Equatable {

    // Bitwarden disabled in settings
    case disabled

    // Bitwarden is not installed
    case notInstalled

    // Installed Bitwarden doesn't support the integration
    case oldVersion
    case incompatible

    // Bitwarden application isn't running
    case notRunning

    // User didn't approve DuckDuckGo browser
    case integrationNotApproved

    // User didn't approve access to sandbox containers
    case accessToContainersNotApproved

    // There is handshake necessary in order to receive the shared key
    case missingHandshake

    // Waiting for the handshake approval in Bitwarden
    case waitingForHandshakeApproval

    // User dismissed the handshake dialog in Bitwarden
    case handshakeNotApproved

    // The proxy process is starting to run
    case connecting

    // We sent the status message and are waiting for the response
    case waitingForStatusResponse

    case connected(vault: BWVault)
    case error(error: BWError)

    var isConnected: Bool {
        switch self {
        case .connected: return true
        default: return false
        }
    }

}
