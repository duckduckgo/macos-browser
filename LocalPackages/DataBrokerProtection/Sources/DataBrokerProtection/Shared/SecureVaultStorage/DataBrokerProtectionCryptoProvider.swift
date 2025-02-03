//
//  DataBrokerProtectionCryptoProvider.swift
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
import BrowserServicesKit
import SecureStorage

final class DataBrokerProtectionCryptoProvider: SecureStorageCryptoProvider {
    var passwordSalt: Data {
        return "DD2D983B-288F-465D-A5DB-9B9D2C7CF784".data(using: .utf8)!
    }

    var keychainServiceName: String {
        return "DuckDuckGo DataBrokerProtection Secure Vault Hash"
    }

    var keychainAccountName: String {
        return Bundle.main.bundleIdentifier ?? "com.duckduckgo.macos.browser"
    }
}
