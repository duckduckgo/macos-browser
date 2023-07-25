//
//  HTTPUtils.swift
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

import Foundation

struct HTTPUtils {
    private static let authToken = "" // Use DBP API Dev Access Token on Bitwarden
    private static let fakeBrokerUsername = ""
    private static let fakeBrokerPassword = ""

    static let authorizationHeader = "bearer \(authToken)"

    static func fetchFakeBrokerCredentials() -> (username: String, password: String) {
        if fakeBrokerUsername.isEmpty || fakeBrokerPassword.isEmpty {
            fatalError("Empty fake broker credentials. Did you forget to add them?")
        }

        return (fakeBrokerUsername, fakeBrokerPassword)
    }
}
