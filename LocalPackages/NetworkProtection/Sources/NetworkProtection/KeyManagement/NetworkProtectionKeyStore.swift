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

/// Generates and stores instances of a PrivateKey on behalf of the user. This key is used to derive a PublicKey which is then used for registration with the Network Protection backend servers.
/// The key is reused between servers (that is, each user currently gets a single key), though this will change in the future to periodically refresh the key.
public final class NetworkProtectionKeychainKeyStore: NetworkProtectionKeyStore {
    private let keychainStore: NetworkProtectionKeychainStore
    private let userDefaults: UserDefaults
    private let errorEvents: EventMapping<NetworkProtectionError>?

    private struct Defaults {
        static let serviceName = "DuckDuckGo Network Protection Private Key"
        static let validityInterval = TimeInterval.day
    }

    private enum UserDefaultKeys {
        static let expirationDate = "com.duckduckgo.network-protection.KeyPair.UserDefaultKeys.expirationDate"
        static let currentPublicKey = "com.duckduckgo.network-protection.NetworkProtectionKeychainStore.UserDefaultKeys.currentPublicKeyBase64"
    }

    public init(serviceName: String? = nil,
                useSystemKeychain: Bool,
                userDefaults: UserDefaults = .standard,
                errorEvents: EventMapping<NetworkProtectionError>?) {

        let keychainServiceName = serviceName ?? Defaults.serviceName
        keychainStore = NetworkProtectionKeychainStore(serviceName: keychainServiceName,
                                                       useSystemKeychain: useSystemKeychain)
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
#if DEBUG
        self.validityInterval = validityInterval ?? Defaults.validityInterval
#else
        // No-op
#endif
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
            try keychainStore.deleteAll()

            self.currentPublicKey = nil
            self.currentExpirationDate = nil
        } catch {
            handle(error)
            // Intentionally not re-throwing
        }
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
                guard let data = try keychainStore.readData(named: currentPublicKey) else {
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
                try keychainStore.deleteAll()
            } catch {
                handle(error)
                // Intentionally not re-throwing
            }

            guard let newValue = newValue else {
                return
            }

            do {
                currentPublicKey = newValue.publicKey.base64Key
                try keychainStore.writeData(newValue.rawValue, named: newValue.publicKey.base64Key)
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
