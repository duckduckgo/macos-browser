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

// swiftlint:disable identifier_name
let DataBrokerProtectionSecureVaultFactory: DataBrokerProtectionVaultFactory = SecureVaultFactory<DefaultDataBrokerProtectionSecureVault>(
    makeCryptoProvider: {
        return DataBrokerProtectionCryptoProvider()
    }, makeKeyStoreProvider: {
        return DataBrokerProtectionKeyStoreProvider()
    }, makeDatabaseProvider: { key in
        return try DefaultDataBrokerProtectionDatabaseProvider(key: key)
    }
)
// swiftlint:enable identifier_name

protocol DataBrokerProtectionSecureVault: SecureVault {
    func save(profile: DataBrokerProtectionProfile) throws -> Int64
    func fetchProfile(with id: Int64) throws -> DataBrokerProtectionProfile?

    func save(broker: DataBroker) throws -> Int64
    func fetchBroker(with id: Int64) throws -> DataBroker?
    func fetchAllBrokers() throws -> [DataBroker]

    func save(profileQuery: ProfileQuery, profileId: Int64) throws -> Int64
    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery?

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws
    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanOperationData?
    func fetchAllScans() throws -> [ScanOperationData]

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws
    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutOperationData?
    func fetchAllOptOuts() throws -> [OptOutOperationData]

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws
    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func fetchEvents(brokerId: Int64, profileQueryId: Int64) throws -> [HistoryEvent]

    func save(extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64
    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfile?
    func fetchExtractedProfiles(for brokerId: Int64, with profileQueryId: Int64) throws -> [ExtractedProfile]
    func updateRemovedDate(for extractedProfileId: Int64, with date: Date) throws
}

final class DefaultDataBrokerProtectionSecureVault<T: DataBrokerProtectionDatabaseProvider>: DataBrokerProtectionSecureVault {
    typealias DataBrokerProtectionStorageProviders = SecureStorageProviders<T>

    private let providers: DataBrokerProtectionStorageProviders
    private let lock = NSLock()

    required init(providers: DataBrokerProtectionStorageProviders) {
        self.providers = providers
    }

    func save(profile: DataBrokerProtectionProfile) throws -> Int64 {
        try executeThrowingDatabaseOperation {
            return try self.providers.database.saveProfile(profile: profile, mapperToDB: MapperToDB(mechanism: l2Encrypt(data:)))
        }
    }

    func fetchProfile(with id: Int64) throws -> DataBrokerProtectionProfile? {
        try executeThrowingDatabaseOperation {
            let profile = try self.providers.database.fetchProfile(with: id)

            if let profile = profile {
                let mapper = MapperToModel(mechanism: l2Decrypt(data:))
                return try mapper.mapToModel(profile)
            } else {
                return nil // Profile not found
            }
        }
    }

    func save(broker: DataBroker) throws -> Int64 {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToDB(mechanism: l2Encrypt(data:))
            return try self.providers.database.save(mapper.mapToDB(broker))
        }
    }

    func fetchBroker(with id: Int64) throws -> DataBroker? {
        try executeThrowingDatabaseOperation {
            if let broker = try self.providers.database.fetchBroker(with: 1) {
                let mapper = MapperToModel(mechanism: l2Decrypt(data:))
                return try mapper.mapToModel(broker)
            }

            return nil
        }
    }

    func fetchAllBrokers() throws -> [DataBroker] {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))

            return try self.providers.database.fetchAllBrokers().map(mapper.mapToModel(_:))
        }
    }

    func save(profileQuery: ProfileQuery, profileId: Int64) throws -> Int64 {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToDB(mechanism: l2Encrypt(data:))
            return try self.providers.database.save(mapper.mapToDB(profileQuery, relatedTo: profileId))
        }
    }

    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery? {
        try executeThrowingDatabaseOperation {
            let profileQuery = try self.providers.database.fetchProfileQuery(with: id)

            if let profileQuery = profileQuery {
                let mapper = MapperToModel(mechanism: l2Decrypt(data:))
                return try mapper.mapToModel(profileQuery)
            } else {
                return nil // ProfileQuery not found
            }
        }
    }

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        try executeThrowingDatabaseOperation {
            try self.providers.database.save(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                lastRunDate: lastRunDate,
                preferredRunDate: preferredRunDate
            )
        }
    }

    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanOperationData? {
        try executeThrowingDatabaseOperation {
            if let scanDB = try self.providers.database.fetchScan(brokerId: brokerId, profileQueryId: profileQueryId) {
                let mapper = MapperToModel(mechanism: l2Decrypt(data:))
                return mapper.mapToModel(scanDB)
            } else {
                return nil // Scan not found
            }
        }
    }

    func fetchAllScans() throws -> [ScanOperationData] {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))

            return try self.providers.database.fetchAllScans().map(mapper.mapToModel(_:))
        }
    }

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        try executeThrowingDatabaseOperation {
            try self.providers.database.save(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                lastRunDate: lastRunDate,
                preferredRunDate: preferredRunDate
            )
        }
    }

    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutOperationData? {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            if let optOutResult = try self.providers.database.fetchOptOut(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId) {
                return try mapper.mapToModel(optOutResult.optOutDB, extractedProfileDB: optOutResult.extractedProfileDB)
            } else {
                return nil // OptOut not found
            }
        }
    }

    func fetchAllOptOuts() throws -> [OptOutOperationData] {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))

            return try self.providers.database.fetchAllOptOuts().map {
                try mapper.mapToModel($0.optOutDB, extractedProfileDB: $0.extractedProfileDB)
            }
        }
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToDB(mechanism: l2Encrypt(data:))

            try self.providers.database.save(mapper.mapToDB(historyEvent, brokerId: brokerId, profileQueryId: profileQueryId))
        }
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToDB(mechanism: l2Encrypt(data:))

            try self.providers.database.save(mapper.mapToDB(historyEvent, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId))
        }
    }

    func fetchEvents(brokerId: Int64, profileQueryId: Int64) throws -> [HistoryEvent] {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            let scanEvents = try self.providers.database.fetchScanEvents(brokerId: brokerId, profileQueryId: profileQueryId).map(mapper.mapToModel(_:))
            let optOutEvents = try self.providers.database.fetchOptOutEvents(brokerId: brokerId, profileQueryId: profileQueryId).map(mapper.mapToModel(_:))

            return scanEvents + optOutEvents
        }
    }

    func save(extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64 {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToDB(mechanism: l2Encrypt(data:))

            return try self.providers.database.save(mapper.mapToDB(extractedProfile, brokerId: brokerId, profileQueryId: profileQueryId))
        }
    }

    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfile? {
        try executeThrowingDatabaseOperation {
            if let extractedProfile = try self.providers.database.fetchExtractedProfile(with: id) {
                let mapper = MapperToModel(mechanism: l2Decrypt(data:))
                return try mapper.mapToModel(extractedProfile)
            } else {
                return nil // No extracted profile found
            }
        }
    }

    func fetchExtractedProfiles(for brokerId: Int64, with profileQueryId: Int64) throws -> [ExtractedProfile] {
        try executeThrowingDatabaseOperation {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            let extractedProfiles = try self.providers.database.fetchExtractedProfiles(for: brokerId, with: profileQueryId)

            return try extractedProfiles.map(mapper.mapToModel(_:))
        }
    }

    func updateRemovedDate(for extractedProfileId: Int64, with date: Date) throws {
        try executeThrowingDatabaseOperation {
            try self.providers.database.updateRemovedDate(for: extractedProfileId, with: date)
        }
    }

    // MARK: - Private methods

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
