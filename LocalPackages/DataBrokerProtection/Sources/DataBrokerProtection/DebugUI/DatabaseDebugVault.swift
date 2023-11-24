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
import SecureStorage

typealias DebugVaultFactory = SecureVaultFactory<DatabaseDebugSecureVault<DefaultDataBrokerProtectionDatabaseProvider>>

let DebugSecureVaultFactory: DebugVaultFactory = SecureVaultFactory<DatabaseDebugSecureVault<DefaultDataBrokerProtectionDatabaseProvider>>(
    makeCryptoProvider: {
        return DataBrokerProtectionCryptoProvider()
    }, makeKeyStoreProvider: {
        return DataBrokerProtectionKeyStoreProvider()
    }, makeDatabaseProvider: { key in
        return try DefaultDataBrokerProtectionDatabaseProvider(key: key)
    }
)


final class DatabaseDebugSecureVault<T: DataBrokerProtectionDatabaseProvider>: SecureVault {
    typealias DataBrokerProtectionStorageProviders = SecureStorageProviders<T>

    private let providers: DataBrokerProtectionStorageProviders

    required init(providers: DataBrokerProtectionStorageProviders) {
        self.providers = providers
    }

    func fetchAllScans() -> [ScanDB] {
        let scans = try? providers.database.fetchAllScans()
        return scans ?? [ScanDB]()
    }

}
