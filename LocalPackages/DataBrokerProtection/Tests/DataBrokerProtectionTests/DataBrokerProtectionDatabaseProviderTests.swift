//
//  DataBrokerProtectionDatabaseProviderTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import XCTest
import GRDB
@testable import DataBrokerProtection

private extension DataBrokerProtectionDatabaseProvider {
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

final class DataBrokerProtectionDatabaseProviderTests: XCTestCase {

    typealias Migrations = DefaultDataBrokerProtectionDatabaseMigrationsProvider

    private var sut: DataBrokerProtectionDatabaseProvider!
    private let vaultURL = DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: "DBP", fileName: "Test-Vault.db")
    private let key = "9CA59EDC-5CE8-4F53-AAC6-286A7378F384".data(using: .utf8)!

    override func setUpWithError() throws {
        do {
            // Sets up a test vault and restores data (with violations) from a `test-vault.sql` file
            sut = try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v2Migrations)
            let fileURL = Bundle.module.url(forResource: "test-vault", withExtension: "sql", subdirectory: "Resources")!
            try sut.restoreDatabase(from: fileURL)
        } catch {
            XCTFail("Failed to create test-vault and insert data")
        }
    }

    override func tearDownWithError() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: vaultURL.path) {
            do {
                try fileManager.removeItem(at: vaultURL)
            } catch {
                XCTFail("Failed to delete test-vault")
            }
        }
        MockMigrationsProvider.didCallV2Migrations = false
        MockMigrationsProvider.didCallV3Migrations = false
        MockMigrationsProvider.didCallV4Migrations = false
        MockMigrationsProvider.didCallV5Migrations = false
    }

    func testV3MigrationCleansUpOrphanedRecords_andResultsInNoDataIntegrityIssues() throws {
        // Given
        let failingMigration: (inout DatabaseMigrator) throws -> Void = { migrator in
            migrator.registerMigration("v3") { database in
                try database.checkForeignKeys()
            }
        }

        let passingMigration: (inout DatabaseMigrator) throws -> Void = { migrator in
            migrator.registerMigration("v4") { database in
                try database.checkForeignKeys()
            }
        }

        XCTAssertThrowsError(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: failingMigration))

        // When
        XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v3Migrations))

        // Then
        XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: passingMigration))
    }

    func testV3MigrationRecreatesTablesWithCascadingDeletes_andDeletingProfileQueryDeletesDependentRecords() throws {
        // Given
        XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v5Migrations))
        XCTAssertEqual(try sut.fetchAllScans().filter { $0.profileQueryId == 43 }.count, 50)
        let allBrokerIds = try sut.fetchAllBrokers().map { $0.id! }
        var allExtractedProfiles = try allBrokerIds.flatMap { try sut.fetchExtractedProfiles(for: $0, with: 43) }
        let extractedProfileId = allExtractedProfiles.first!.id
        var optOutAttempt = try sut.fetchAttemptInformation(for: extractedProfileId!)
        var allOptOuts = try allBrokerIds.flatMap { try sut.fetchOptOuts(brokerId: $0, profileQueryId: 43) }
        var allScanHistoryEvents = try allBrokerIds.flatMap { try sut.fetchScanEvents(brokerId: $0, profileQueryId: 43) }
        var allOptOutHistoryEvents = try allBrokerIds.flatMap { try sut.fetchOptOutEvents(brokerId: $0, profileQueryId: 43) }
        XCTAssertNotNil(optOutAttempt)
        XCTAssertEqual(allExtractedProfiles.count, 1)
        XCTAssertEqual(allOptOuts.count, 1)
        XCTAssertEqual(allScanHistoryEvents.count, 656)
        XCTAssertEqual(allOptOutHistoryEvents.count, 4)
        let profileQuery = try sut.fetchProfileQuery(with: 43)!

        // When
        try sut.delete(profileQuery)

        // Then
        XCTAssertEqual(try sut.fetchAllScans().filter { $0.profileQueryId == 43 }.count, 0)
        allExtractedProfiles = try allBrokerIds.flatMap { try sut.fetchExtractedProfiles(for: $0, with: 43) }
        optOutAttempt = try sut.fetchAttemptInformation(for: extractedProfileId!)
        allOptOuts = try allBrokerIds.flatMap { try sut.fetchOptOuts(brokerId: $0, profileQueryId: 43) }
        allScanHistoryEvents = try allBrokerIds.flatMap { try sut.fetchScanEvents(brokerId: $0, profileQueryId: 43) }
        allOptOutHistoryEvents = try allBrokerIds.flatMap { try sut.fetchOptOutEvents(brokerId: $0, profileQueryId: 43) }
        XCTAssertNil(optOutAttempt)
        XCTAssertEqual(allExtractedProfiles.count, 0)
        XCTAssertEqual(allOptOuts.count, 0)
        XCTAssertEqual(allScanHistoryEvents.count, 0)
        XCTAssertEqual(allOptOutHistoryEvents.count, 0)
    }

    func testV3MigrationOfDatabaseWithLotsOfIntegrityIssues() throws {

        var length = 10
        var start: Int64 = 1000
        var end: Int64 = 2000

        repeat {

            // Given
            do {
                try sut.db.writeWithoutTransaction { db in
                    try db.execute(sql: "PRAGMA foreign_keys = OFF")
                }

                let profileQueries = ProfileQueryDB.random(withProfileIds: Int64.randomValues(ofLength: length, start: start, end: end))
                for query in profileQueries {
                    _ = try sut.save(query)
                }

                for broker in BrokerDB.random(count: length) {
                    _ = try sut.save(broker)
                }

                let brokerIds = Int64.randomValues(ofLength: length, start: start, end: end)
                let profileQueryIds = Int64.randomValues(ofLength: length, start: start, end: end)
                let extractedProfileIds = Int64.randomValues(ofLength: length, start: start, end: end)

                for scanHistoryEvent in ScanHistoryEventDB.random(withBrokerIds: brokerIds, profileQueryIds: profileQueryIds) {
                    _ = try sut.save(scanHistoryEvent)
                }

                for optOutHistoryEvent in OptOutHistoryEventDB.random(withBrokerIds: brokerIds, profileQueryIds: profileQueryIds, extractedProfileIds: extractedProfileIds) {
                    _ = try sut.save(optOutHistoryEvent)
                }

                for extractedProfile in ExtractedProfileDB.random(withBrokerIds: brokerIds, profileQueryIds: profileQueryIds) {
                    _ = try sut.save(extractedProfile)
                }

                try sut.db.writeWithoutTransaction { db in
                    try db.execute(sql: "PRAGMA foreign_keys = ON")
                }

            } catch {
                XCTFail("Failed to setup invalid data")
            }

            let failingMigration: (inout DatabaseMigrator) throws -> Void = { migrator in
                migrator.registerMigration("v3") { database in
                    try database.checkForeignKeys()
                }
            }

            let passingMigration: (inout DatabaseMigrator) throws -> Void = { migrator in
                migrator.registerMigration("v4") { database in
                    try database.checkForeignKeys()
                }
            }

            XCTAssertThrowsError(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: failingMigration))

            // When
            XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v3Migrations))

            // Then
            XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: passingMigration))

            length += 1
            start += (start/2)
            end += (end/2)

            try tearDownWithError()
            try setUpWithError()

        } while length < 20
    }

    func testV4Migration() throws {
        // Given
        XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v5Migrations))

        // When
        let optOuts = try sut.fetchAllOptOuts()
        let optOut = optOuts.first!.optOutDB

        // Then
        XCTAssertNil(optOut.submittedSuccessfullyDate)
        XCTAssertFalse(optOut.sevenDaysConfirmationPixelFired)
        XCTAssertFalse(optOut.fourteenDaysConfirmationPixelFired)
        XCTAssertFalse(optOut.twentyOneDaysConfirmationPixelFired)

    }

    func testV5Migration() throws {
        // Given
        XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v5Migrations))

        // When
        let optOuts = try sut.fetchAllOptOuts()
        let optOut = optOuts.first!.optOutDB

        // Then
        XCTAssertEqual(optOut.attemptCount, 0)
    }

    func testDeleteAllDataSucceedsInRemovingAllData() throws {
        XCTAssertFalse(try sut.db.allTablesAreEmpty())
        XCTAssertNoThrow(try sut.deleteProfileData())
        XCTAssertTrue(try sut.db.allTablesAreEmpty())
    }
}

private extension DatabaseWriter {

    func allTablesAreEmpty() throws -> Bool {
        return try self.read { db in
            // Get the list of all tables
            let tableNames = try String.fetchAll(db, sql: """
                SELECT name
                FROM sqlite_master
                WHERE type = 'table'
                  AND name NOT LIKE 'sqlite_%';
            """)

            // Check if all tables are empty, ignoring our migrations table
            for tableName in tableNames where tableName != "grdb_migrations" {
                let rowCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(tableName)") ?? 0
                if rowCount > 0 {
                    return false
                }
            }
            return true
        }
    }
}
