//
//  NetworkProtectionKeyStore.swift
//  DuckDuckGo
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Common
import Foundation
import os

public protocol NetworkProtectionKeyStore {
    
    /// Obtain the current private key.
    ///
    func currentPrivateKey() -> PrivateKey

    /// Retrieves an existing stored private key.
    ///
    /// - Throws: NetworkProtectionKeychainStoreError
    func storedPrivateKey() throws -> PrivateKey?

    /// Resets the current private key so a new one will be generated when requested.
    ///
    func resetCurrentKey()
    
}

enum NetworkProtectionKeychainStoreError: Error, NetworkProtectionErrorConvertible {
    case failedToCastKeychainValueToData(field: String)
    case keychainReadError(field: String, status: Int32)
    case keychainWriteError(field: String, status: Int32)
    case keychainDeleteError(field: String, status: Int32)

    var networkProtectionError: NetworkProtectionError {
        switch self {
        case .failedToCastKeychainValueToData(let field): return .failedToCastKeychainValueToData(field: field)
        case .keychainReadError(let field, let status): return .keychainReadError(field: field, status: status)
        case .keychainWriteError(let field, let status): return .keychainWriteError(field: field, status: status)
        case .keychainDeleteError(let field, let status): return .keychainDeleteError(field: field, status: status)
        }
    }
}

/// Generates and stores instances of a PrivateKey on behalf of the user. This key is used to derive a PublicKey which is then used for registration with the Network Protection backend servers.
/// The key is reused between servers (that is, each user currently gets a single key), though this will change in the future to periodically refresh the key.
public class NetworkProtectionKeychainStore: NetworkProtectionKeyStore {

    struct Constants {
        static let defaultServiceName = "DuckDuckGo Network Protection Private Key"
        static let privateKeyName = "DuckDuckGo Network Protection Private Key"
    }

    private let serviceName: String
    private let useSystemKeychain: Bool
    private let errorEvents: EventMapping<NetworkProtectionError>?

    public convenience init(useSystemKeychain: Bool, errorEvents: EventMapping<NetworkProtectionError>?) {
        self.init(serviceName: Constants.defaultServiceName, useSystemKeychain: useSystemKeychain, errorEvents: errorEvents)
    }

    init(serviceName: String, useSystemKeychain: Bool, errorEvents: EventMapping<NetworkProtectionError>?) {
        self.serviceName = serviceName
        self.useSystemKeychain = useSystemKeychain
        self.errorEvents = errorEvents
    }

    // MARK: - NetworkProtectionKeyStore

    /// Retrieves the stored private key without generating one if it doesn't exist.
    ///
    public func storedPrivateKey() throws -> PrivateKey? {        
        do {
            guard let data = try readData(named: Constants.privateKeyName) else {
                return nil
            }

            return PrivateKey(rawValue: data)
        } catch {
            handle(error)
            throw error
        }
    }

    public func currentPrivateKey() -> PrivateKey {
        do {
            if let existingkey = try storedPrivateKey() {
                return existingkey
            }
        } catch {
            handle(error)
            // Intentionally not re-throwing
        }

        let generatedKey = PrivateKey()
        
        do {
            try writeData(generatedKey.rawValue, named: Constants.privateKeyName)
        } catch {
            handle(error)
            // Intentionally not re-throwing
        }

        return generatedKey
    }

    /// Resets the current key, so that a new one will be generated the next time it's retrieved.
    ///
    public func resetCurrentKey() {
        do {
            try deleteEntry(named: Constants.privateKeyName)
        } catch {
            handle(error)
            // Intentionally not re-throwing
        }
    }

    // MARK: - Keychain Interaction

    private func readData(named name: String) throws -> Data? {
        var query = defaultAttributesForEntry(named: name)
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

    private func writeData(_ data: Data, named name: String) throws {
        var query = defaultAttributesForEntry(named: name)
        query[kSecAttrService as String] = serviceName
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw NetworkProtectionKeychainStoreError.keychainWriteError(field: name, status: status)
        }
    }

    private func deleteEntry(named name: String) throws {
        let query = defaultAttributesForEntry(named: name)

        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecItemNotFound, errSecSuccess: break
        default:
            throw NetworkProtectionKeychainStoreError.keychainDeleteError(field: name, status: status)
        }
    }

    private func defaultAttributesForEntry(named name: String) -> [String: Any] {        
        return [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: !useSystemKeychain,
            kSecAttrSynchronizable: false,
            kSecAttrAccount: name
        ] as [String: Any]
    }
    
    // MARK: - EventMapping
    
    private func handle(_ error: Error) {
        guard let error = error as? NetworkProtectionKeychainStoreError else {
            assertionFailure("Failed to cast Network Protection Keychain store error")
            errorEvents?.fire(NetworkProtectionError.unhandledError(function: #function, line: #line, error: error))
            return
        }
        
        errorEvents?.fire(error.networkProtectionError)
    }
}
