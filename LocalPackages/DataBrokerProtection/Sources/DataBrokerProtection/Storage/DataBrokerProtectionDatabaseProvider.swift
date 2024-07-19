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

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfile: ExtractedProfileDB, lastRunDate: Date?, preferredRunDate: Date?) throws
    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws
    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws
    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> (optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)?
    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [(optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB)]
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

    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> OptOutAttemptDB?
    func save(_ optOutAttemptDB: OptOutAttemptDB) throws

    // Test Helper Methods
    func dumpDatabase(to url: URL) throws
    func restoreDatabase(from url: URL) throws
 }

extension DataBrokerProtectionDatabaseProvider {

    func dumpDatabase(to url: URL) throws {
        try db.read { db in
            var sqlDump = ""

            // Get the list of tables
            let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")

            // Dump data for each table
            for table in tables {
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM \(table)")
                for row in rows {
                    let columns = row.columnNames.joined(separator: ", ")
                    let values = row.map { $0.1.sqlExpression }.joined(separator: ", ")
                    sqlDump += "INSERT INTO \(table) (\(columns)) VALUES (\(values));\n"
                }
                sqlDump += "\n"
            }

            // Save to file
            try sqlDump.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func restoreDatabase(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let sqlDump = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Invalid SQL dump file", code: 1, userInfo: nil)
        }

        // Filter SQL statements to exclude GRDB migrations table data
        let sqlStatements = sqlDump.components(separatedBy: ";\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !$0.contains("INSERT INTO grdb_migrations") }

        try db.writeWithoutTransaction { db in

            // Disable & enable foreign keys to ignore constraint violations
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            for statement in sqlStatements {
                try db.execute(sql: statement)
            }
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
    }
}

final class DefaultDataBrokerProtectionDatabaseProvider: GRDBSecureStorageDatabaseProvider, DataBrokerProtectionDatabaseProvider {

    public static func defaultDatabaseURL() -> URL {
        return DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: "DBP", fileName: "Vault.db", appGroupIdentifier: Bundle.main.appGroupName)
    }

    public init(file: URL = DefaultDataBrokerProtectionDatabaseProvider.defaultDatabaseURL(),
                key: Data,
                registerMigrationsHandler: (inout DatabaseMigrator) throws -> Void = Migrations.v2Migrations) throws {
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

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfile: ExtractedProfileDB, lastRunDate: Date?, preferredRunDate: Date?) throws {
        try db.write { db in
            try extractedProfile.insert(db)
            let extractedProfileId = db.lastInsertedRowID
            try OptOutDB(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                lastRunDate: lastRunDate,
                preferredRunDate: preferredRunDate
            ).insert(db)
        }
    }

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        try db.write { db in
            try OptOutDB(
                brokerId: brokerId,
                profileQueryId: profileQueryId,
                extractedProfileId: extractedProfileId,
                lastRunDate: lastRunDate,
                preferredRunDate: preferredRunDate
            ).insert(db)
        }
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try db.write { db in
            if var optOut = try OptOutDB.fetchOne(db, key: [
                OptOutDB.Columns.brokerId.name: brokerId,
                OptOutDB.Columns.profileQueryId.name: profileQueryId,
                OptOutDB.Columns.extractedProfileId.name: extractedProfileId]) {
                optOut.preferredRunDate = date
                try optOut.update(db)
            } else {
                throw DataBrokerProtectionDatabaseErrors.elementNotFound
            }
        }
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
        try db.write { db in
            if var optOut = try OptOutDB.fetchOne(db, key: [
                OptOutDB.Columns.brokerId.name: brokerId,
                OptOutDB.Columns.profileQueryId.name: profileQueryId,
                OptOutDB.Columns.extractedProfileId.name: extractedProfileId]) {
                optOut.lastRunDate = date
                try optOut.update(db)
            } else {
                throw DataBrokerProtectionDatabaseErrors.elementNotFound
            }
        }
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

    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> OptOutAttemptDB? {
        try db.read { db in
            return try OptOutAttemptDB.fetchOne(db, key: extractedProfileId)
        }
    }

    func save(_ optOutAttemptDB: OptOutAttemptDB) throws {
        try db.write { db in
            try optOutAttemptDB.insert(db)
        }
    }
}

extension DatabaseValue {
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

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
