//
//  BWKeyStorage.swift
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

protocol BWKeyStoring {

    func save(sharedKey: Base64EncodedString) throws
    func retrieveSharedKey() throws -> Base64EncodedString?
    func cleanSharedKey() throws

}

final class BWKeyStorage: BWKeyStoring {

    enum BitwardenKeyStorageError: Error {
        case failedToSaveKey(status: OSStatus)
        case failedToEncodeKey
        case failedToDecodeKey
        case failedToRetrieveKey(status: OSStatus)
        case failedToCleanKey(status: OSStatus)
    }

    private static let keychainKey = "\(Bundle.main.bundleIdentifier ?? "").bitwarden.shared.key"

    func save(sharedKey: Base64EncodedString) throws {
        try cleanSharedKey()

        guard let data = Data(base64Encoded: sharedKey) else {
            throw BitwardenKeyStorageError.failedToDecodeKey
        }
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrSynchronizable: false,
            kSecAttrService: Self.keychainKey,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: true] as [String: Any]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw BitwardenKeyStorageError.failedToSaveKey(status: status)
        }
    }

    func cleanSharedKey() throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrSynchronizable: false,
            kSecAttrService: Self.keychainKey,
            kSecUseDataProtectionKeychain: true] as [String: Any]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw BitwardenKeyStorageError.failedToCleanKey(status: status)
        }
    }

    func retrieveSharedKey() throws -> Base64EncodedString? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrService: Self.keychainKey,
            kSecReturnData: true,
            kSecUseDataProtectionKeychain: true] as [String: Any]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess {
            if let existingItem = item as? Data {
                let key = existingItem.base64EncodedString()
                return key
            } else {
                throw BitwardenKeyStorageError.failedToEncodeKey
            }
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw BitwardenKeyStorageError.failedToRetrieveKey(status: status)
        }
    }

}
