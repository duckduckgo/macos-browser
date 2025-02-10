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
    }, makeKeyStoreProvider: { _ in
        return DataBrokerProtectionKeyStoreProvider()
    }, makeDatabaseProvider: { key in
        try DefaultDataBrokerProtectionDatabaseProvider.create(key: key)
    }
)
// swiftlint:enable identifier_name

protocol DataBrokerProtectionSecureVault: SecureVault {
    func save(profile: DataBrokerProtectionProfile) throws -> Int64
    func update(profile: DataBrokerProtectionProfile) throws -> Int64
    func fetchProfile(with id: Int64) throws -> DataBrokerProtectionProfile?
    func deleteProfileData() throws

    func save(broker: DataBroker) throws -> Int64
    func update(_ broker: DataBroker, with id: Int64) throws
    func fetchBroker(with id: Int64) throws -> DataBroker?
    func fetchBroker(with name: String) throws -> DataBroker?
    func fetchAllBrokers() throws -> [DataBroker]
    func fetchChildBrokers(for parentBroker: String) throws -> [DataBroker]

    func save(profileQuery: ProfileQuery, profileId: Int64) throws -> Int64
    func delete(profileQuery: ProfileQuery, profileId: Int64) throws
    func update(_ profileQuery: ProfileQuery, brokerIDs: [Int64], profileId: Int64) throws -> Int64
    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery?
    func fetchAllProfileQueries(for profileId: Int64) throws -> [ProfileQuery]

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws
    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws
    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanJobData?
    func fetchAllScans() throws -> [ScanJobData]

    func save(brokerId: Int64,
              profileQueryId: Int64,
              extractedProfile: ExtractedProfile,
              createdDate: Date,
              lastRunDate: Date?,
              preferredRunDate: Date?,
              attemptCount: Int64,
              submittedSuccessfullyDate: Date?,
              sevenDaysConfirmationPixelFired: Bool,
              fourteenDaysConfirmationPixelFired: Bool,
              twentyOneDaysConfirmationPixelFired: Bool) throws
    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func updateAttemptCount(_ count: Int64, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func incrementAttemptCount(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func updateSubmittedSuccessfullyDate(_ date: Date?,
                                         forBrokerId brokerId: Int64,
                                         profileQueryId: Int64,
                                         extractedProfileId: Int64) throws
    func updateSevenDaysConfirmationPixelFired(_ pixelFired: Bool,
                                               forBrokerId brokerId: Int64,
                                               profileQueryId: Int64,
                                               extractedProfileId: Int64) throws
    func updateFourteenDaysConfirmationPixelFired(_ pixelFired: Bool,
                                                  forBrokerId brokerId: Int64,
                                                  profileQueryId: Int64,
                                                  extractedProfileId: Int64) throws
    func updateTwentyOneDaysConfirmationPixelFired(_ pixelFired: Bool,
                                                   forBrokerId brokerId: Int64,
                                                   profileQueryId: Int64,
                                                   extractedProfileId: Int64) throws
    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutJobData?
    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [OptOutJobData]
    func fetchOptOuts(brokerId: Int64) throws -> [OptOutJobData]
    func fetchAllOptOuts() throws -> [OptOutJobData]

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws
    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func fetchEvents(brokerId: Int64, profileQueryId: Int64) throws -> [HistoryEvent]

    func save(extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64
    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfile?
    func fetchExtractedProfiles(for brokerId: Int64, with profileQueryId: Int64) throws -> [ExtractedProfile]
    func fetchExtractedProfiles(for brokerId: Int64) throws -> [ExtractedProfile]
    func updateRemovedDate(for extractedProfileId: Int64, with date: Date?) throws

    func hasMatches() throws -> Bool

    func fetchAllAttempts() throws -> [AttemptInformation]
    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> AttemptInformation?
    func save(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) throws
}

final class DefaultDataBrokerProtectionSecureVault<T: DataBrokerProtectionDatabaseProvider>: DataBrokerProtectionSecureVault {
    typealias DataBrokerProtectionStorageProviders = SecureStorageProviders<T>

    private let providers: DataBrokerProtectionStorageProviders

    required init(providers: DataBrokerProtectionStorageProviders) {
        self.providers = providers
    }

    func save(profile: DataBrokerProtectionProfile) throws -> Int64 {
        return try self.providers.database.saveProfile(profile: profile, mapperToDB: MapperToDB(mechanism: l2Encrypt(data:)))
    }

    func update(profile: DataBrokerProtectionProfile) throws -> Int64 {
        return try self.providers.database.updateProfile(profile: profile, mapperToDB: MapperToDB(mechanism: l2Encrypt(data:)))
    }

    func fetchProfile(with id: Int64) throws -> DataBrokerProtectionProfile? {
        let profile = try self.providers.database.fetchProfile(with: id)

        if let profile = profile {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            return try mapper.mapToModel(profile)
        } else {
            return nil // Profile not found
        }
    }

    func deleteProfileData() throws {
        try self.providers.database.deleteProfileData()
    }

    func save(broker: DataBroker) throws -> Int64 {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))
        return try self.providers.database.save(mapper.mapToDB(broker))
    }

    func update(_ broker: DataBroker, with id: Int64) throws {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))
        return try self.providers.database.update(mapper.mapToDB(broker, id: id))
    }

    func fetchBroker(with id: Int64) throws -> DataBroker? {
        if let broker = try self.providers.database.fetchBroker(with: id) {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            return try mapper.mapToModel(broker)
        }

        return nil
    }

    func fetchBroker(with name: String) throws -> DataBroker? {
        if let broker = try self.providers.database.fetchBroker(with: name) {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            return try mapper.mapToModel(broker)
        }

        return nil
    }

    func fetchAllBrokers() throws -> [DataBroker] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))

        return try self.providers.database.fetchAllBrokers().map(mapper.mapToModel(_:))
    }

    func fetchChildBrokers(for parentBroker: String) throws -> [DataBroker] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        let brokers = try self.providers.database.fetchAllBrokers().map(mapper.mapToModel(_:))

        return brokers.filter { $0.parent == parentBroker }
    }

    func save(profileQuery: ProfileQuery, profileId: Int64) throws -> Int64 {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))
        return try self.providers.database.save(mapper.mapToDB(profileQuery, relatedTo: profileId))
    }

    func delete(profileQuery: ProfileQuery, profileId: Int64) throws {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))
        return try self.providers.database.delete(mapper.mapToDB(profileQuery, relatedTo: profileId))
    }

    func update(_ profileQuery: ProfileQuery, brokerIDs: [Int64], profileId: Int64) throws -> Int64 {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))
        let profileQueryDB = try mapper.mapToDB(profileQuery, relatedTo: profileId)

        return try self.providers.database.update(profileQueryDB)
    }

    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery? {
        let profileQuery = try self.providers.database.fetchProfileQuery(with: id)

        if let profileQuery = profileQuery {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            return try mapper.mapToModel(profileQuery)
        } else {
            return nil // ProfileQuery not found
        }
    }

    func fetchAllProfileQueries(for profileId: Int64) throws -> [ProfileQuery] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        return try self.providers.database.fetchAllProfileQueries(for: profileId).map(mapper.mapToModel(_:))
    }

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        try self.providers.database.save(
            brokerId: brokerId,
            profileQueryId: profileQueryId,
            lastRunDate: lastRunDate,
            preferredRunDate: preferredRunDate
        )
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
        try self.providers.database.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
        try self.providers.database.updateLastRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
    }

    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanJobData? {
        if let scanDB = try self.providers.database.fetchScan(brokerId: brokerId, profileQueryId: profileQueryId) {
            let scanEvents = try self.providers.database.fetchScanEvents(brokerId: brokerId, profileQueryId: profileQueryId)
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))

            return try mapper.mapToModel(scanDB, events: scanEvents)
        } else {
            return nil // Scan not found
        }
    }

    func fetchAllScans() throws -> [ScanJobData] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        var scans = [ScanJobData]()
        let scansDB = try self.providers.database.fetchAllScans()

        for scan in scansDB {
            let scanEvents = try self.providers.database.fetchScanEvents(brokerId: scan.brokerId, profileQueryId: scan.profileQueryId)
            scans.append(try mapper.mapToModel(scan, events: scanEvents))
        }

        return scans
    }

    func save(brokerId: Int64,
              profileQueryId: Int64,
              extractedProfile: ExtractedProfile,
              createdDate: Date,
              lastRunDate: Date?,
              preferredRunDate: Date?,
              attemptCount: Int64,
              submittedSuccessfullyDate: Date?,
              sevenDaysConfirmationPixelFired: Bool,
              fourteenDaysConfirmationPixelFired: Bool,
              twentyOneDaysConfirmationPixelFired: Bool) throws {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))
        let extractedProfileDB = try mapper.mapToDB(extractedProfile, brokerId: brokerId, profileQueryId: profileQueryId)
        try self.providers.database.save(
            brokerId: brokerId,
            profileQueryId: profileQueryId,
            extractedProfile: extractedProfileDB,
            createdDate: createdDate,
            lastRunDate: lastRunDate,
            preferredRunDate: preferredRunDate,
            attemptCount: attemptCount,
            submittedSuccessfullyDate: submittedSuccessfullyDate,
            sevenDaysConfirmationPixelFired: sevenDaysConfirmationPixelFired,
            fourteenDaysConfirmationPixelFired: fourteenDaysConfirmationPixelFired,
            twentyOneDaysConfirmationPixelFired: twentyOneDaysConfirmationPixelFired
        )
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try self.providers.database.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try self.providers.database.updateLastRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
    }

    func updateAttemptCount(_ count: Int64, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try self.providers.database.updateAttemptCount(count, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
    }

    func incrementAttemptCount(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try self.providers.database.incrementAttemptCount(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
    }

    func updateSubmittedSuccessfullyDate(_ date: Date?,
                                         forBrokerId brokerId: Int64,
                                         profileQueryId: Int64,
                                         extractedProfileId: Int64) throws {
        try self.providers.database.updateSubmittedSuccessfullyDate(date, forBrokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
    }

    func updateSevenDaysConfirmationPixelFired(_ pixelFired: Bool,
                                               forBrokerId brokerId: Int64,
                                               profileQueryId: Int64,
                                               extractedProfileId: Int64) throws {
        try self.providers.database.updateSevenDaysConfirmationPixelFired(pixelFired,
                                                                          forBrokerId: brokerId,
                                                                          profileQueryId: profileQueryId,
                                                                          extractedProfileId: extractedProfileId)
    }

    func updateFourteenDaysConfirmationPixelFired(_ pixelFired: Bool,
                                                  forBrokerId brokerId: Int64,
                                                  profileQueryId: Int64,
                                                  extractedProfileId: Int64) throws {
        try self.providers.database.updateFourteenDaysConfirmationPixelFired(pixelFired,
                                                                             forBrokerId: brokerId,
                                                                             profileQueryId: profileQueryId,
                                                                             extractedProfileId: extractedProfileId)
    }

    func updateTwentyOneDaysConfirmationPixelFired(_ pixelFired: Bool,
                                                   forBrokerId brokerId: Int64,
                                                   profileQueryId: Int64,
                                                   extractedProfileId: Int64) throws {
        try self.providers.database.updateTwentyOneDaysConfirmationPixelFired(pixelFired,
                                                                              forBrokerId: brokerId,
                                                                              profileQueryId: profileQueryId,
                                                                              extractedProfileId: extractedProfileId)
    }

    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutJobData? {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        if let optOutResult = try self.providers.database.fetchOptOut(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId) {
            let optOutEvents = try self.providers.database.fetchOptOutEvents(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
            return try mapper.mapToModel(optOutResult.optOutDB, extractedProfileDB: optOutResult.extractedProfileDB, events: optOutEvents)
        } else {
            return nil // OptOut not found
        }
    }

    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [OptOutJobData] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))

        return try self.providers.database.fetchOptOuts(brokerId: brokerId, profileQueryId: profileQueryId).map {
            let optOutEvents = try self.providers.database.fetchOptOutEvents(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: $0.optOutDB.extractedProfileId
            )
            return try mapper.mapToModel($0.optOutDB, extractedProfileDB: $0.extractedProfileDB, events: optOutEvents)
        }
    }

    func fetchOptOuts(brokerId: Int64) throws -> [OptOutJobData] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))

        return try self.providers.database.fetchOptOuts(brokerId: brokerId).map {
            let optOutEvents = try self.providers.database.fetchOptOutEvents(
                brokerId: brokerId,
                profileQueryId: $0.optOutDB.profileQueryId,
                extractedProfileId: $0.optOutDB.extractedProfileId
            )
            return try mapper.mapToModel($0.optOutDB, extractedProfileDB: $0.extractedProfileDB, events: optOutEvents)
        }
    }

    func fetchAllOptOuts() throws -> [OptOutJobData] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))

        return try self.providers.database.fetchAllOptOuts().map {
            let optOutEvents = try self.providers.database.fetchOptOutEvents(
                brokerId: $0.optOutDB.brokerId,
                profileQueryId: $0.optOutDB.profileQueryId,
                extractedProfileId: $0.optOutDB.extractedProfileId
            )
            return try mapper.mapToModel($0.optOutDB, extractedProfileDB: $0.extractedProfileDB, events: optOutEvents)
        }
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))

        try self.providers.database.save(mapper.mapToDB(historyEvent, brokerId: brokerId, profileQueryId: profileQueryId))
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))

        try self.providers.database.save(mapper.mapToDB(historyEvent, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId))
    }

    func fetchEvents(brokerId: Int64, profileQueryId: Int64) throws -> [HistoryEvent] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        let scanEvents = try self.providers.database.fetchScanEvents(brokerId: brokerId, profileQueryId: profileQueryId).map(mapper.mapToModel(_:))
        let optOutEvents = try self.providers.database.fetchOptOutEvents(brokerId: brokerId, profileQueryId: profileQueryId).map(mapper.mapToModel(_:))

        return scanEvents + optOutEvents
    }

    func save(extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64 {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))

        return try self.providers.database.save(mapper.mapToDB(extractedProfile, brokerId: brokerId, profileQueryId: profileQueryId))
    }

    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfile? {
        if let extractedProfile = try self.providers.database.fetchExtractedProfile(with: id) {
            let mapper = MapperToModel(mechanism: l2Decrypt(data:))
            return try mapper.mapToModel(extractedProfile)
        } else {
            return nil // No extracted profile found
        }
    }

    func fetchExtractedProfiles(for brokerId: Int64, with profileQueryId: Int64) throws -> [ExtractedProfile] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        let extractedProfiles = try self.providers.database.fetchExtractedProfiles(for: brokerId, with: profileQueryId)

        return try extractedProfiles.map(mapper.mapToModel(_:))
    }

    func fetchExtractedProfiles(for brokerId: Int64) throws -> [ExtractedProfile] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        let extractedProfiles = try self.providers.database.fetchExtractedProfiles(for: brokerId)

        return try extractedProfiles.map(mapper.mapToModel(_:))
    }

    func updateRemovedDate(for extractedProfileId: Int64, with date: Date?) throws {
        try self.providers.database.updateRemovedDate(for: extractedProfileId, with: date)
    }

    func hasMatches() throws -> Bool {
        try self.providers.database.hasMatches()
    }

    func fetchAllAttempts() throws -> [AttemptInformation] {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        return try self.providers.database.fetchAllAttempts().map(mapper.mapToModel(_:))
    }

    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> AttemptInformation? {
        let mapper = MapperToModel(mechanism: l2Decrypt(data:))
        if let attemptDB = try self.providers.database.fetchAttemptInformation(for: extractedProfileId) {
            return mapper.mapToModel(attemptDB)
        } else {
            return nil
        }
    }

    func save(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) throws {
        let mapper = MapperToDB(mechanism: l2Encrypt(data:))
        try self.providers.database.save(mapper.mapToDB(extractedProfileId: extractedProfileId,
                                                        attemptUUID: attemptUUID,
                                                        dataBroker: dataBroker,
                                                        lastStageDate: lastStageDate,
                                                        startTime: startTime))
    }

    // MARK: - Private methods

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
