//
//  MockNetworkProtectionCodeRedeemer.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

#if NETWORK_PROTECTION

import Foundation
import NetworkProtection

final class MockNetworkProtectionCodeRedeemer: NetworkProtectionCodeRedeeming {

    enum MockNetworkProtectionCodeRedeemerError: Error {
        case error
    }

    var throwError: Bool = false

    var redeemedCode: String?
    func redeem(_ code: String) async throws {
        if throwError {
            throw MockNetworkProtectionCodeRedeemerError.error
        } else {
            redeemedCode = code
        }
    }

    var redeemedAccessToken: String?
    func exchange(accessToken: String) async throws {
        if throwError {
            throw MockNetworkProtectionCodeRedeemerError.error
        } else {
            redeemedAccessToken = accessToken
        }
    }

}

#endif
