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

    /// Obtain the current `KeyPair`.
    ///
    func currentKeyPair() -> KeyPair

    /// Sets the validity interval for keys
    ///

    func setValidityInterval(_ validityInterval: TimeInterval?)

    /// Updates the current `KeyPair` to have the specified expiration date
    ///
    /// - Parameters:
    ///     - newExpirationDate: the new expiration date for the keypair
    ///
    /// - Returns: a new keypair with the specified updates
    ///
    func updateCurrentKeyPair(newExpirationDate: Date) -> KeyPair

    /// Resets the current `KeyPair` so a new one will be generated when requested.
    ///
    func resetCurrentKeyPair()
}

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

/// Generates and stores instances of a PrivateKey on behalf of the user. This key is used to derive a PublicKey which is then used for registration with the Network Protection backend servers.
/// The key is reused between servers (that is, each user currently gets a single key), though this will change in the future to periodically refresh the key.
public class NetworkProtectionKeychainStore: NetworkProtectionKeyStore {

    struct Defaults {
        static let serviceName = "DuckDuckGo Network Protection Private Key"
        static let validityInterval = TimeInterval.day
    }

    enum UserDefaultKeys {
        static let expirationDate = "com.duckduckgo.network-protection.KeyPair.UserDefaultKeys.expirationDate"
        static let currentPublicKey = "com.duckduckgo.network-protection.NetworkProtectionKeychainStore.UserDefaultKeys.currentPublicKeyBase64"
    }

    private let serviceName: String
    private let useSystemKeychain: Bool
    private let userDefaults: UserDefaults
    private let errorEvents: EventMapping<NetworkProtectionError>?

    public init(serviceName: String? = nil,
                useSystemKeychain: Bool,
                userDefaults: UserDefaults = .standard,
                errorEvents: EventMapping<NetworkProtectionError>?) {

        self.serviceName = serviceName ?? Defaults.serviceName
        self.useSystemKeychain = useSystemKeychain
        self.userDefaults = userDefaults
        self.errorEvents = errorEvents
    }

    // MARK: - NetworkProtectionKeyStore

    public func currentKeyPair() -> KeyPair {
        os_log("Querying the current key pair (publicKey: %{public}@, expirationDate: %{public}@)",
               log: .networkProtectionKeyManagement,
               type: .info,
               String(describing: currentPublicKey),
               String(describing: currentExpirationDate))

        guard let currentPrivateKey = currentPrivateKey else {
            let keyPair = newCurrentKeyPair()
            os_log("Returning a new key pair as there's no current private key (newPublicKey: %{public}@)",
                   log: .networkProtectionKeyManagement,
                   type: .info,
                   String(describing: keyPair.publicKey.base64Key))
            return keyPair
        }

        guard let currentExpirationDate = currentExpirationDate,
              Date().addingTimeInterval(validityInterval) >= currentExpirationDate else {

            let keyPair = newCurrentKeyPair()
            os_log("Returning a new key pair as the expirationDate date is missing, or we're past it (now: %{public}@, expirationDate: %{public}@)",
                   log: .networkProtectionKeyManagement,
                   type: .info,
                   String(describing: Date()),
                   String(describing: currentExpirationDate))
            return keyPair
        }

        os_log("Returning an existing key pair.",
               log: .networkProtectionKeyManagement,
               type: .info)
        return KeyPair(privateKey: currentPrivateKey, expirationDate: currentExpirationDate)
    }

    private var validityInterval = Defaults.validityInterval

    public func setValidityInterval(_ validityInterval: TimeInterval?) {
        self.validityInterval = validityInterval ?? Defaults.validityInterval
    }

    private func newCurrentKeyPair() -> KeyPair {
        let currentPrivateKey = PrivateKey()
        let currentExpirationDate = Date().addingTimeInterval(validityInterval)

        self.currentPrivateKey = currentPrivateKey
        self.currentExpirationDate = currentExpirationDate

        return KeyPair(privateKey: currentPrivateKey, expirationDate: currentExpirationDate)
    }

    public func updateCurrentKeyPair(newExpirationDate: Date) -> KeyPair {
        currentExpirationDate = newExpirationDate
        return currentKeyPair()
    }

    public func resetCurrentKeyPair() {
        do {
            /// Besides resetting the current keyPair we'll remove all keychain entries associated with our service, since only one keychain entry
            /// should exist at once.
            try deleteAllPrivateKeys()

            self.currentPublicKey = nil
            self.currentExpirationDate = nil
        } catch {
            handle(error)
            // Intentionally not re-throwing
        }
    }

    // MARK: - Keychain Interaction

    private func readData(named name: String) throws -> Data? {
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

    private func writeData(_ data: Data, named name: String) throws {
        var query = defaultAttributes()
        query[kSecAttrAccount as String] = name
        query[kSecAttrService as String] = serviceName
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw NetworkProtectionKeychainStoreError.keychainWriteError(field: name, status: status)
        }
    }

    private func deleteAllPrivateKeys() throws {
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

    // MARK: - UserDefaults

    var currentExpirationDate: Date? {
        get {
            return userDefaults.object(forKey: UserDefaultKeys.expirationDate) as? Date
        }

        set {
            userDefaults.set(newValue, forKey: UserDefaultKeys.expirationDate)
        }
    }

    /// The currently used public key.
    ///
    /// The key is stored in base64 representation.
    ///
    private var currentPublicKey: String? {
        get {
            guard let base64Key = userDefaults.string(forKey: UserDefaultKeys.currentPublicKey) else {
                return nil
            }

            return PublicKey(base64Key: base64Key)?.base64Key
        }

        set {
            userDefaults.set(newValue, forKey: UserDefaultKeys.currentPublicKey)
        }
    }

    private var currentPrivateKey: PrivateKey? {
        get {
            guard let currentPublicKey = currentPublicKey else {
                return nil
            }

            do {
                guard let data = try readData(named: currentPublicKey) else {
                    return nil
                }

                return PrivateKey(rawValue: data)
            } catch {
                handle(error)
                // Intentionally not re-throwing
            }

            return nil
        }

        set {
            do {
                try deleteAllPrivateKeys()
            } catch {
                handle(error)
                // Intentionally not re-throwing
            }

            guard let newValue = newValue else {
                return
            }

            do {
                currentPublicKey = newValue.publicKey.base64Key
                try writeData(newValue.rawValue, named: newValue.publicKey.base64Key)
            } catch {
                handle(error)
                // Intentionally not re-throwing
            }
        }
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
