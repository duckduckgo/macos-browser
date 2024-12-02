//
//  DataBrokerProtectionDatabaseProvider.swift
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
import GRDB

enum DataBrokerProtectionDatabaseErrors: Error {
    case elementNotFound
}

protocol DataBrokerProtectionDatabaseProvider: SecureStorageDatabaseProvider {
    func saveProfile(profile: DataBrokerProtectionProfile, mapperToDB: MapperToDB) throws -> Int64
    func updateProfile(profile: DataBrokerProtectionProfile, mapperToDB: MapperToDB) throws -> Int64
    func fetchProfile(with id: Int64) throws -> FullProfileDB?
    func deleteProfileData() throws

    func save(_ broker: BrokerDB) throws -> Int64
    func update(_ broker: BrokerDB) throws
    func fetchBroker(with id: Int64) throws -> BrokerDB?
    func fetchBroker(with url: String) throws -> BrokerDB?
    func fetchAllBrokers() throws -> [BrokerDB]

    func save(_ profileQuery: ProfileQueryDB) throws -> Int64
    func delete(_ profileQuery: ProfileQueryDB) throws
    func update(_ profileQuery: ProfileQueryDB) throws -> Int64

    func fetchProfileQuery(with id: Int64) throws -> ProfileQueryDB?
    func fetchAllProfileQueries(for profileId: Int64) throws -> [ProfileQueryDB]

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws
    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws
    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanDB?
    func fetchAllScans() throws -> [ScanDB]

    func save(brokerId: Int64,
              profileQueryId: Int64,
              extractedProfile: ExtractedProfileDB,
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
    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> (optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)?
    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)]
    func fetchOptOuts(brokerId: Int64) throws -> [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)]
    func fetchAllOptOuts() throws -> [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)]

    func save(_ scanEvent: ScanHistoryEventDB) throws
    func save(_ optOutEvent: OptOutHistoryEventDB) throws
    func fetchScanEvents(brokerId: Int64, profileQueryId: Int64) throws -> [ScanHistoryEventDB]
    func fetchOptOutEvents(brokerId: Int64, profileQueryId: Int64) throws -> [OptOutHistoryEventDB]
    func fetchOptOutEvents(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> [OptOutHistoryEventDB]

    func save(_ extractedProfile: ExtractedProfileDB) throws -> Int64
    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfileDB?
    func fetchExtractedProfiles(for brokerId: Int64, with profileQueryId: Int64) throws -> [ExtractedProfileDB]
    func fetchExtractedProfiles(for brokerId: Int64) throws -> [ExtractedProfileDB]
    func updateRemovedDate(for extractedProfileId: Int64, with date: Date?) throws

    func hasMatches() throws -> Bool

    func fetchAllAttempts() throws -> [OptOutAttemptDB]
    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> OptOutAttemptDB?
    func save(_ optOutAttemptDB: OptOutAttemptDB) throws
 }

final class DefaultDataBrokerProtectionDatabaseProvider: GRDBSecureStorageDatabaseProvider, DataBrokerProtectionDatabaseProvider {

    typealias MigrationsProvider = DataBrokerProtectionDatabaseMigrationsProvider

    public static func defaultDatabaseURL() -> URL {
        return DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: "DBP", fileName: "Vault.db", appGroupIdentifier: Bundle.main.appGroupName)
    }

    /// Creates a DefaultDataBrokerProtectionDatabaseProvider instance
    /// - Parameters:
    ///   - file: File URL of the database
    ///   - key: Key used in encryption
    ///   - featureFlagger: Migrations feature flagger
    ///   - migrationProvider: Migrations provider
    /// - Returns: DefaultDataBrokerProtectionDatabaseProvider instance
    public static func create<T: MigrationsProvider>(file: URL = DefaultDataBrokerProtectionDatabaseProvider.defaultDatabaseURL(),
                                                     key: Data,
                                                     migrationProvider: T.Type = DefaultDataBrokerProtectionDatabaseMigrationsProvider.self) throws -> DefaultDataBrokerProtectionDatabaseProvider {
        try DefaultDataBrokerProtectionDatabaseProvider(file: file, key: key, registerMigrationsHandler: migrationProvider.v5Migrations)
    }

    public init(file: URL = DefaultDataBrokerProtectionDatabaseProvider.defaultDatabaseURL(),
                key: Data,
                registerMigrationsHandler: (inout DatabaseMigrator) throws -> Void) throws {
        try super.init(file: file, key: key, writerType: .pool, registerMigrationsHandler: registerMigrationsHandler)
    }

    func createFileURLInDocumentsDirectory(fileName: String) -> URL? {
        let fileManager = FileManager.default
        do {
            let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            return fileURL
        } catch {
            print("Error getting documents directory: \(error.localizedDescription)")
            return nil
        }
    }

    func updateProfile(profile: DataBrokerProtectionProfile, mapperToDB: MapperToDB) throws -> Int64 {
        try db.write { db in

            // The schema currently supports multiple profiles, but we are going to start with a single one
            let profileId: Int64 = 1
            try mapperToDB.mapToDB(id: profileId, profile: profile).upsert(db)

            try NameDB.deleteAll(db)
            for name in profile.names {
                try mapperToDB.mapToDB(name, relatedTo: profileId).insert(db)
            }

            try AddressDB.deleteAll(db)
            for address in profile.addresses {
                try mapperToDB.mapToDB(address, relatedTo: profileId).insert(db)
            }

            try PhoneDB.deleteAll(db)
            for phone in profile.phones {
                try mapperToDB.mapToDB(phone, relatedTo: profileId).insert(db)
            }

            return profileId
        }
    }

    func saveProfile(profile: DataBrokerProtectionProfile, mapperToDB: MapperToDB) throws -> Int64 {
        try db.write { db in

            // The schema currently supports multiple profiles, but we are going to start with a single one
            let profileId: Int64 = 1
            try mapperToDB.mapToDB(id: profileId, profile: profile).insert(db)

            for name in profile.names {
                try mapperToDB.mapToDB(name, relatedTo: profileId).insert(db)
            }

            for address in profile.addresses {
                try mapperToDB.mapToDB(address, relatedTo: profileId).insert(db)
            }

            for phone in profile.phones {
                try mapperToDB.mapToDB(phone, relatedTo: profileId).insert(db)
            }

            return profileId
        }
    }

    func fetchProfile(with id: Int64) throws -> FullProfileDB? {
        try db.read { database in
            let request = ProfileDB.including(all: ProfileDB.names)
                .including(all: ProfileDB.addresses)
                .including(all: ProfileDB.phoneNumbers)
            return try FullProfileDB.fetchOne(database, request)
        }
    }

    func deleteProfileData() throws {
        try db.write { db in
            try OptOutHistoryEventDB
                .deleteAll(db)
            try OptOutDB
                .deleteAll(db)
            try ScanHistoryEventDB
                .deleteAll(db)
            try ScanDB
                .deleteAll(db)
            try OptOutAttemptDB
                .deleteAll(db)
            try ExtractedProfileDB
                .deleteAll(db)
            try ProfileQueryDB
                .deleteAll(db)
            try NameDB
                .deleteAll(db)
            try AddressDB
                .deleteAll(db)
            try PhoneDB
                .deleteAll(db)
            try BrokerDB
                .deleteAll(db)
            try ProfileDB
                .deleteAll(db)
        }
    }

    func save(_ broker: BrokerDB) throws -> Int64 {
        try db.write { db in
            try broker.insert(db)
            return db.lastInsertedRowID
        }
    }

    func update(_ broker: BrokerDB) throws {
        try db.write { db in
            try broker.update(db)
        }
    }

    func fetchBroker(with id: Int64) throws -> BrokerDB? {
        try db.read { db in
            return try BrokerDB.fetchOne(db, key: id)
        }
    }

    func fetchBroker(with url: String) throws -> BrokerDB? {
        try db.read { db in
            return try BrokerDB
                .filter(Column(BrokerDB.Columns.url.name) == url)
                .fetchOne(db)
        }
    }

    func fetchAllBrokers() throws -> [BrokerDB] {
        try db.read { db in
            return try BrokerDB.fetchAll(db)
        }
    }

    func save(_ profileQuery: ProfileQueryDB) throws -> Int64 {
        try db.write { db in
            try profileQuery.insert(db)
            return db.lastInsertedRowID
        }
    }

    func update(_ profileQuery: ProfileQueryDB) throws -> Int64 {
        try db.write { db in
            if let id = profileQuery.id {
                try profileQuery.update(db)
                return id
            } else {
                try profileQuery.insert(db)
                return db.lastInsertedRowID
            }
        }
    }

    func delete(_ profileQuery: ProfileQueryDB) throws {
        guard let profileQueryID = profileQuery.id else { throw DataBrokerProtectionDatabaseErrors.elementNotFound }
        _ = try db.write { db in
            try ProfileQueryDB
                .filter(Column(ProfileQueryDB.Columns.id.name) == profileQueryID)
                .deleteAll(db)
        }
    }

    func fetchProfileQuery(with id: Int64) throws -> ProfileQueryDB? {
        try db.read { db in
            return try ProfileQueryDB.fetchOne(db, key: id)
        }
    }

    func fetchAllProfileQueries(for profileId: Int64) throws -> [ProfileQueryDB] {
        try db.read { db in
            return try ProfileQueryDB
                .filter(Column(ProfileQueryDB.Columns.profileId.name) == profileId)
                .fetchAll(db)
        }
    }

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        try db.write { db in
            try ScanDB(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                lastRunDate: lastRunDate,
                preferredRunDate: preferredRunDate
            ).insert(db)
        }
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
        try db.write { db in
            if var scan = try ScanDB.fetchOne(db, key: [ScanDB.Columns.brokerId.name: brokerId, ScanDB.Columns.profileQueryId.name: profileQueryId]) {
                scan.preferredRunDate = date
                try scan.update(db)
            } else {
                throw DataBrokerProtectionDatabaseErrors.elementNotFound
            }
        }
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
        try db.write { db in
            if var scan = try ScanDB.fetchOne(db, key: [ScanDB.Columns.brokerId.name: brokerId, ScanDB.Columns.profileQueryId.name: profileQueryId]) {
                scan.lastRunDate = date
                try scan.update(db)
            } else {
                throw DataBrokerProtectionDatabaseErrors.elementNotFound
            }
        }
    }

    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanDB? {
        try db.read { db in
            return try ScanDB.fetchOne(db, key: [ScanDB.Columns.brokerId.name: brokerId, ScanDB.Columns.profileQueryId.name: profileQueryId])
        }
    }

    func fetchAllScans() throws -> [ScanDB] {
        try db.read { db in
            return try ScanDB.fetchAll(db)
        }
    }

    func save(brokerId: Int64,
              profileQueryId: Int64,
              extractedProfile: ExtractedProfileDB,
              createdDate: Date,
              lastRunDate: Date?,
              preferredRunDate: Date?,
              attemptCount: Int64,
              submittedSuccessfullyDate: Date?,
              sevenDaysConfirmationPixelFired: Bool,
              fourteenDaysConfirmationPixelFired: Bool,
              twentyOneDaysConfirmationPixelFired: Bool) throws {
        try db.write { db in
            try extractedProfile.insert(db)
            let extractedProfileId = db.lastInsertedRowID
            try OptOutDB(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                createdDate: createdDate,
                lastRunDate: lastRunDate,
                preferredRunDate: preferredRunDate,
                attemptCount: attemptCount,
                submittedSuccessfullyDate: submittedSuccessfullyDate,
                sevenDaysConfirmationPixelFired: sevenDaysConfirmationPixelFired,
                fourteenDaysConfirmationPixelFired: fourteenDaysConfirmationPixelFired,
                twentyOneDaysConfirmationPixelFired: twentyOneDaysConfirmationPixelFired
            ).insert(db)
        }
    }

    private func updateOptOutField<T>(_ fieldUpdate: @escaping (inout OptOutDB, T) -> Void,
                                      value: T,
                                      forBrokerId brokerId: Int64,
                                      profileQueryId: Int64,
                                      extractedProfileId: Int64) throws {
        try db.write { db in
            if var optOut = try OptOutDB.fetchOne(db, key: [
                OptOutDB.Columns.brokerId.name: brokerId,
                OptOutDB.Columns.profileQueryId.name: profileQueryId,
                OptOutDB.Columns.extractedProfileId.name: extractedProfileId]) {
                fieldUpdate(&optOut, value)
                try optOut.update(db)
            } else {
                throw DataBrokerProtectionDatabaseErrors.elementNotFound
            }
        }
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try updateOptOutField({ $0.preferredRunDate = $1 },
                              value: date, forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try updateOptOutField({ $0.lastRunDate = $1 },
                              value: date,
                              forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func updateAttemptCount(_ count: Int64, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try updateOptOutField({ $0.attemptCount = $1 },
                              value: count,
                              forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func incrementAttemptCount(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try updateOptOutField({ optOut, _ in optOut.attemptCount += 1 },
                              value: -1,
                              forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func updateSubmittedSuccessfullyDate(_ date: Date?,
                                         forBrokerId brokerId: Int64,
                                         profileQueryId: Int64,
                                         extractedProfileId: Int64) throws {
        try updateOptOutField({ $0.submittedSuccessfullyDate = $1 },
                              value: date, forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func updateSevenDaysConfirmationPixelFired(_ pixelFired: Bool,
                                               forBrokerId brokerId: Int64,
                                               profileQueryId: Int64,
                                               extractedProfileId: Int64) throws {
        try updateOptOutField({ $0.sevenDaysConfirmationPixelFired = $1 },
                              value: pixelFired, forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func updateFourteenDaysConfirmationPixelFired(_ pixelFired: Bool,
                                                  forBrokerId brokerId: Int64,
                                                  profileQueryId: Int64,
                                                  extractedProfileId: Int64) throws {
        try updateOptOutField({ $0.fourteenDaysConfirmationPixelFired = $1 },
                              value: pixelFired, forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func updateTwentyOneDaysConfirmationPixelFired(_ pixelFired: Bool,
                                                   forBrokerId brokerId: Int64,
                                                   profileQueryId: Int64,
                                                   extractedProfileId: Int64) throws {
        try updateOptOutField({ $0.twentyOneDaysConfirmationPixelFired = $1 },
                              value: pixelFired, forBrokerId: brokerId,
                              profileQueryId: profileQueryId,
                              extractedProfileId: extractedProfileId)
    }

    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> (optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)? {
        try db.read { db in
            if let optOut = try OptOutDB.fetchOne(db, key: [
                OptOutDB.Columns.brokerId.name: brokerId,
                OptOutDB.Columns.profileQueryId.name: profileQueryId,
                OptOutDB.Columns.extractedProfileId.name: extractedProfileId]
            ), let extractedProfile = try optOut.extractedProfile.fetchOne(db) {
                return (optOut, extractedProfile)
            }

            return nil
        }
    }

    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)] {
        try db.read { db in
            var optOutsWithExtractedProfiles = [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)]()
            let optOuts = try OptOutDB
                .filter(Column(OptOutDB.Columns.brokerId.name) == brokerId && Column(OptOutDB.Columns.profileQueryId.name) == profileQueryId)
                .fetchAll(db)

            for optOut in optOuts {
                if let extractedProfile = try optOut.extractedProfile.fetchOne(db) {
                    optOutsWithExtractedProfiles.append((optOutDB: optOut, extractedProfileDB: extractedProfile))
                }
            }

            return optOutsWithExtractedProfiles
        }
    }

    func fetchOptOuts(brokerId: Int64) throws -> [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)] {
        try db.read { db in
            var optOutsWithExtractedProfiles = [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)]()
            let optOuts = try OptOutDB
                .filter(Column(OptOutDB.Columns.brokerId.name) == brokerId)
                .fetchAll(db)

            for optOut in optOuts {
                if let extractedProfile = try optOut.extractedProfile.fetchOne(db) {
                    optOutsWithExtractedProfiles.append((optOutDB: optOut, extractedProfileDB: extractedProfile))
                }
            }

            return optOutsWithExtractedProfiles
        }
    }

    func fetchAllOptOuts() throws -> [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)] {
        try db.read { db in
            var optOutsWithExtractedProfiles = [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)]()
            let optOuts = try OptOutDB.fetchAll(db)

            for optOut in optOuts {
                if let extractedProfile = try optOut.extractedProfile.fetchOne(db) {
                    optOutsWithExtractedProfiles.append((optOutDB: optOut, extractedProfileDB: extractedProfile))
                }
            }

            return optOutsWithExtractedProfiles
        }
    }

    func save(_ scanEvent: ScanHistoryEventDB) throws {
        try db.write { db in
            try scanEvent.insert(db)
        }
    }

    func save(_ optOutEvent: OptOutHistoryEventDB) throws {
        try db.write { db in
            try optOutEvent.insert(db)
        }
    }

    func fetchScanEvents(brokerId: Int64, profileQueryId: Int64) throws -> [ScanHistoryEventDB] {
        try db.read { db in
            return try ScanHistoryEventDB
                .filter(Column(ScanHistoryEventDB.Columns.brokerId.name) == brokerId &&
                        Column(ScanHistoryEventDB.Columns.profileQueryId.name) == profileQueryId)
                .fetchAll(db)
        }
    }

    func fetchOptOutEvents(brokerId: Int64, profileQueryId: Int64) throws -> [OptOutHistoryEventDB] {
        try db.read { db in
            return try OptOutHistoryEventDB
                .filter(Column(OptOutHistoryEventDB.Columns.brokerId.name) == brokerId &&
                        Column(OptOutHistoryEventDB.Columns.profileQueryId.name) == profileQueryId)
                .fetchAll(db)
        }
    }

    func fetchOptOutEvents(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> [OptOutHistoryEventDB] {
        try db.read { db in
            return try OptOutHistoryEventDB
                .filter(Column(OptOutHistoryEventDB.Columns.brokerId.name) == brokerId &&
                        Column(OptOutHistoryEventDB.Columns.profileQueryId.name) == profileQueryId &&
                        Column(OptOutHistoryEventDB.Columns.extractedProfileId.name) == extractedProfileId)
                .fetchAll(db)
        }
    }

    func save(_ extractedProfile: ExtractedProfileDB) throws -> Int64 {
        try db.write { db in
            try extractedProfile.insert(db)
            return db.lastInsertedRowID
        }
    }

    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfileDB? {
        try db.read { db in
            return try ExtractedProfileDB.fetchOne(db, key: id)
        }
    }

    func fetchExtractedProfiles(for brokerId: Int64, with profileQueryId: Int64) throws -> [ExtractedProfileDB] {
        try db.read { db in
            return try ExtractedProfileDB
                .filter(Column(ExtractedProfileDB.Columns.brokerId.name) == brokerId &&
                        Column(ExtractedProfileDB.Columns.profileQueryId.name) == profileQueryId)
                .fetchAll(db)
        }
    }

    func fetchExtractedProfiles(for brokerId: Int64) throws -> [ExtractedProfileDB] {
        try db.read { db in
            return try ExtractedProfileDB
                .filter(Column(ExtractedProfileDB.Columns.brokerId.name) == brokerId)
                .fetchAll(db)
        }
    }

    func updateRemovedDate(for extractedProfileId: Int64, with date: Date?) throws {
        try db.write { db in
            if var extractedProfile = try ExtractedProfileDB.fetchOne(db, key: extractedProfileId) {
                extractedProfile.removedDate = date
                try extractedProfile.update(db)
            } else {
                throw DataBrokerProtectionDatabaseErrors.elementNotFound
            }
        }
    }

    func hasMatches() throws -> Bool {
        try db.read { db in
            return try OptOutDB.fetchCount(db) > 0
        }
    }

    func fetchAllAttempts() throws -> [OptOutAttemptDB] {
        try db.read { db in
            return try OptOutAttemptDB.fetchAll(db)
        }
    }

    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> OptOutAttemptDB? {
        try db.read { db in
            return try OptOutAttemptDB.fetchOne(db, key: extractedProfileId)
        }
    }

    func save(_ optOutAttemptDB: OptOutAttemptDB) throws {
        try db.write { db in
            // We originally intended for ExtractedProfileDB to have a one-to-many relationship with OptOutAttemptDB,
            // but it somehow ended up as a one-to-one relationship instead.
            //
            // This serves as a temporary workaround to keep the opt-out retry mechanism functioning.
            // We'll need to address this issue properly in the future.
            //
            // https://app.asana.com/0/1205591970852438/1208761697124514/f
            try optOutAttemptDB.upsert(db)
        }
    }
}

private extension DatabaseValue {

    /// Returns the SQL representation of the `DatabaseValue`.
    ///
    /// This converts the database value to a string that can be used in an SQL statement.
    ///
    /// - Returns: A `String` representing the SQL expression of the `DatabaseValue`.
    var sqlExpression: String {
        switch storage {
        case .null:
            return "NULL"
        case .int64(let int64):
            return "\(int64)"
        case .double(let double):
            return "\(double)"
        case .string(let string):
            return "'\(string.replacingOccurrences(of: "'", with: "''"))'"
        case .blob(let data):
            return "X'\(data.hexEncodedString())'"
        }
    }
}

private extension Data {

    /// Converts `Data` to a hexadecimal string representation.
    ///
    /// Used to format data so it can be inserted into SQL statements.
    ///
    /// - Returns: A `String` representing the hexadecimal encoding of the data.
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
