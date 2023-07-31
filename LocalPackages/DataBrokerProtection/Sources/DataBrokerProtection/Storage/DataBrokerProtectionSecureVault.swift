//
//  DataBrokerProtectionSecureVault.swift
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

typealias DataBrokerProtectionVaultFactory = SecureVaultFactory<DefaultDataBrokerProtectionSecureVault<DefaultDataBrokerProtectionDatabaseProvider>>

let DataBrokerProtectionSecureVaultFactory: DataBrokerProtectionVaultFactory = SecureVaultFactory<DefaultDataBrokerProtectionSecureVault>(
    makeCryptoProvider: {
        return DataBrokerProtectionCryptoProvider()
    }, makeKeyStoreProvider: {
        return DataBrokerProtectionKeyStoreProvider()
    }, makeDatabaseProvider: { key in
        return try DefaultDataBrokerProtectionDatabaseProvider(key: key)
    }
)

protocol DataBrokerProtectionSecureVault: SecureVault {
    func saveProfile(profile: ProfileDB) throws -> Int64
    func fetchProfile(with id: Int64) throws -> ProfileDB?
}

final class DefaultDataBrokerProtectionSecureVault<T: DataBrokerProtectionDatabaseProvider>: DataBrokerProtectionSecureVault {
    typealias DataBrokerProtectionStorageProviders = SecureStorageProviders<T>

    private let providers: DataBrokerProtectionStorageProviders
    private let lock = NSLock()

    required init(providers: DataBrokerProtectionStorageProviders) {
        self.providers = providers
    }

    func saveProfile(profile: ProfileDB) throws -> Int64 {
        try executeThrowingDatabaseOperation {
            return try self.providers.database.saveProfile(profile: profile.encrypt(l2Encrypt))
        }
    }

    func fetchProfile(with id: Int64) throws -> ProfileDB? {
        try executeThrowingDatabaseOperation {
            return try self.providers.database.fetchProfile(with: id)?.decrypt(l2Decrypt)
        }
    }

    private func executeThrowingDatabaseOperation<DatabaseResult>(_ operation: () throws -> DatabaseResult) throws -> DatabaseResult {
        lock.lock()
        defer {
            lock.unlock()
        }

        do {
            return try operation()
        } catch {
            throw error as? SecureStorageError ?? SecureStorageError.databaseError(cause: error)
        }
    }

    private func passwordInUse() throws -> Data {
        if let generatedPassword = try providers.keystore.generatedPassword() {
            return generatedPassword
        }

        throw SecureStorageError.authRequired
    }

    private func l2KeyFrom(password: Data) throws -> Data {
        let decryptionKey = try providers.crypto.deriveKeyFromPassword(password)
        guard let encryptedL2Key = try providers.keystore.encryptedL2Key() else {
            throw SecureStorageError.noL2Key
        }
        return try providers.crypto.decrypt(encryptedL2Key, withKey: decryptionKey)
    }

    private func l2Encrypt(data: Data) throws -> Data {
        let password = try passwordInUse()
        let l2Key = try l2KeyFrom(password: password)
        return try providers.crypto.encrypt(data, withKey: l2Key)
    }

    private func l2Decrypt(data: Data) throws -> Data {
        let password = try passwordInUse()
        let l2Key = try l2KeyFrom(password: password)
        return try providers.crypto.decrypt(data, withKey: l2Key)
    }
}
