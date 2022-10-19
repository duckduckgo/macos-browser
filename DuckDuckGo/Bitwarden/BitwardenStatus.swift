//
//  BitwardenState.swift
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

enum BitwardenStatus: Equatable {

    // Bitwarden disabled in settings
    case disabled

    // Bitwarden application isn't running || User didn't approve DuckDuckGo browser integration
    case notApproachable
    
    // Bitwarden application is running && user enabled DuckDuckGo browser integration, but has not granted connection permission
    case approachable

    case connected(vault: Vault)
    case error(error: BitwardenError)

    struct Vault: Equatable {
        let id: String
        let email: String
        let status: Status
        let active: Bool

        enum Status: String {
            case locked
            case unlocked
        }
    }

}
