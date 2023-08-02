//
//  DataBrokerProtectionKeyStoreProvider.swift
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

final class DataBrokerProtectionKeyStoreProvider: SecureStorageKeyStoreProvider {

    struct Constants {
        static let defaultServiceName = "DataBrokerProtection DuckDuckGo Secure Vault"
    }

    // DO NOT CHANGE except if you want to deliberately invalidate all users's vaults.
    // The keys have a uid to deter casual hacker from easily seeing which keychain entry is related to what.
    private enum EntryName: String {
        case generatedPassword = "5FCE971A-DE67-4649-9A42-5E6DAB026E72"
        case l1Key = "9CA59EDC-5CE8-4F53-AAC6-286A7378F384"
        case l2Key = "E544DC56-1D72-4C5D-9738-FDFA6602C47E"
    }

    var generatedPasswordEntryName: String {
        return EntryName.generatedPassword.rawValue
    }

    var l1KeyEntryName: String {
        return EntryName.l1Key.rawValue
    }

    var l2KeyEntryName: String {
        return EntryName.l2Key.rawValue
    }

    var keychainServiceName: String {
        return Constants.defaultServiceName
    }

    func attributesForEntry(named: String, serviceName: String) -> [String: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: false,
            kSecAttrSynchronizable: false,
            kSecAttrAccount: named
        ] as [String: Any]
    }
}
