//
//  NetworkProtectionKeychainStore+AuthTokenStoring.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Subscription
import NetworkProtection
import Networking

extension NetworkProtectionKeychainStore: @retroactive AuthTokenStoring {
    static var name = "com.duckduckgo.networkprotection.tokenContainer"

    public var tokenContainer: Networking.TokenContainer? {
        get {
            if let data = try? readData(named: Self.name) as? NSData {
                return try? TokenContainer(with: data)
            }
            return nil
        }
        set(newValue) {
            if newValue == nil {
                try? deleteAll()
            } else if let data = newValue?.data as? Data {
                try? writeData(data, named: Self.name)
            }
        }
    }
}
