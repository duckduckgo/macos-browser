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
    func fetchBroker(with id: Int64) throws -> DataBroker
    func fetchBroker(with name: String) throws -> DataBroker

    func save(profileQuery: ProfileQuery) throws -> Int64
    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws
    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanOperationData
    func fetchAllScans() throws -> [ScanOperationData]

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws
    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutOperationData
    func fetchAllOptOuts() throws -> [OptOutOperationData]

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws
    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func fetchEvents(brokerId: Int64) throws -> [HistoryEvent]
    func fetchEvents(profileQueryId: Int64) throws -> [HistoryEvent]

    func save(extractedProfile: ExtractedProfile) throws -> Int64
    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfile
    func fetchExtractedProfiles(for brokerId: Int64, with profileId: Int64) throws -> [ExtractedProfile]
    func updateRemovedDate(for extractedProfile: ExtractedProfile, with date: Date) throws
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
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            let profile = try self.providers.database.fetchProfile(with: id)

            if let profile = profile {
                return try mapper.mapToModel(profile)
            } else {
                return nil // Profile not found
            }
        }
    }

    func save(broker: DataBroker) throws -> Int64 {
        fatalError("Not implemented.")
    }

    func fetchBroker(with id: Int64) throws -> DataBroker {
        fatalError("Not implemented.")
    }

    func fetchBroker(with name: String) throws -> DataBroker {
        fatalError("Not implemented.")
    }

    func save(profileQuery: ProfileQuery) throws -> Int64 {
        fatalError("Not implemented.")
    }

    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery {
        fatalError("Not implemented.")
    }

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        fatalError("Not implemented.")
    }

    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanOperationData {
        fatalError("Not implemented.")
    }

    func fetchAllScans() throws -> [ScanOperationData] {
        fatalError("Not implemented.")
    }

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        fatalError("Not implemented.")
    }

    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutOperationData {
        fatalError("Not implemented.")
    }

    func fetchAllOptOuts() throws -> [OptOutOperationData] {
        fatalError("Not implemented.")
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws {
        fatalError("Not implemented.")
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        fatalError("Not implemented.")
    }

    func fetchEvents(brokerId: Int64) throws -> [HistoryEvent] {
        fatalError("Not implemented.")
    }

    func fetchEvents(profileQueryId: Int64) throws -> [HistoryEvent] {
        fatalError("Not implemented.")
    }

    func save(extractedProfile: ExtractedProfile) throws -> Int64 {
        fatalError("Not implemented.")
    }

    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfile {
        fatalError("Not implemented.")
    }

    func fetchExtractedProfiles(for brokerId: Int64, with profileId: Int64) throws -> [ExtractedProfile] {
        fatalError("Not implemented.")
    }

    func updateRemovedDate(for extractedProfile: ExtractedProfile, with date: Date) throws {
        fatalError("Not implemented.")
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
