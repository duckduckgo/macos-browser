//
//  NetworkProtectionKeychainStore.swift
//  DuckDuckGo
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
import Common

enum NetworkProtectionKeychainStoreError: Error, NetworkProtectionErrorConvertible {
    case failedToCastKeychainValueToData(field: String)
    case keychainReadError(field: String, status: Int32)
    case keychainWriteError(field: String, status: Int32)
    case keychainDeleteError(status: Int32)

    var networkProtectionError: NetworkProtectionError {
        switch self {
        case .failedToCastKeychainValueToData(let field): return .failedToCastKeychainValueToData(field: field)
        case .keychainReadError(let field, let status): return .keychainReadError(field: field, status: status)
        case .keychainWriteError(let field, let status): return .keychainWriteError(field: field, status: status)
        case .keychainDeleteError(let status): return .keychainDeleteError(status: status)
        }
    }
}

/// General Keychain access helper class for the NetworkProtection module. Should be used for specific KeychainStore types.
final class NetworkProtectionKeychainStore {
    private let serviceName: String
    private let useSystemKeychain: Bool

    init(serviceName: String,
         useSystemKeychain: Bool) {

        self.serviceName = serviceName
        self.useSystemKeychain = useSystemKeychain
    }

    // MARK: - Keychain Interaction

    func readData(named name: String) throws -> Data? {
        var query = defaultAttributes()
        query[kSecAttrAccount as String] = name
        query[kSecReturnData as String] = true

        var item: CFTypeRef?

        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw NetworkProtectionKeychainStoreError.failedToCastKeychainValueToData(field: name)
            }

            return data
        case errSecItemNotFound:
            return nil
        default:
            os_log("🔵 SecItemCopyMatching status %{public}@", type: .error, String(describing: status))
            throw NetworkProtectionKeychainStoreError.keychainReadError(field: name, status: status)
        }
    }

    func writeData(_ data: Data, named name: String) throws {
        var query = defaultAttributes()
        query[kSecAttrAccount as String] = name
        query[kSecAttrService as String] = serviceName
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw NetworkProtectionKeychainStoreError.keychainWriteError(field: name, status: status)
        }
    }

    func deleteAll() throws {
        var query = defaultAttributes()
        query[kSecAttrService as String] = serviceName
        query[kSecMatchLimit as String] = kSecMatchLimitAll

        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecItemNotFound, errSecSuccess:
            break
        default:
            throw NetworkProtectionKeychainStoreError.keychainDeleteError(status: status)
        }
    }

    private func defaultAttributes() -> [String: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: !useSystemKeychain,
            kSecAttrSynchronizable: false
        ] as [String: Any]
    }
}
