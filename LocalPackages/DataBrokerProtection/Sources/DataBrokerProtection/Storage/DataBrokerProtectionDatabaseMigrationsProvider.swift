//
//  DataBrokerProtectionDatabaseMigrationsProvider.swift
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

import Foundation
import GRDB
import Common
import os.log

enum DataBrokerProtectionDatabaseMigrationErrors: Error {
    case deleteOrphanedRecordFailed
    case recreateTablesFailed
    case foreignKeyViolation
}

/// Conforming types provide migrations for the PIR database. Mostly utilized for testing.
protocol DataBrokerProtectionDatabaseMigrationsProvider {
    static var v2Migrations: (inout DatabaseMigrator) throws -> Void { get }
    static var v3Migrations: (inout DatabaseMigrator) throws -> Void { get }
    static var v4Migrations: (inout DatabaseMigrator) throws -> Void { get }
    static var v5Migrations: (inout DatabaseMigrator) throws -> Void { get }
}

final class DefaultDataBrokerProtectionDatabaseMigrationsProvider: DataBrokerProtectionDatabaseMigrationsProvider {

    static var v2Migrations: (inout DatabaseMigrator) throws -> Void = { migrator in
        migrator.registerMigration("v1", migrate: migrateV1(database:))
        migrator.registerMigration("v2", migrate: migrateV2(database:))
    }

    static var v3Migrations: (inout DatabaseMigrator) throws -> Void = { migrator in
        migrator.registerMigration("v1", migrate: migrateV1(database:))
        migrator.registerMigration("v2", migrate: migrateV2(database:))
        migrator.registerMigration("v3", migrate: migrateV3(database:))
    }

    static var v4Migrations: (inout DatabaseMigrator) throws -> Void = { migrator in
        migrator.registerMigration("v1", migrate: migrateV1(database:))
        migrator.registerMigration("v2", migrate: migrateV2(database:))
        migrator.registerMigration("v3", migrate: migrateV3(database:))
        migrator.registerMigration("v4", migrate: migrateV4(database:))
    }

    static var v5Migrations: (inout DatabaseMigrator) throws -> Void = { migrator in
        migrator.registerMigration("v1", migrate: migrateV1(database:))
        migrator.registerMigration("v2", migrate: migrateV2(database:))
        migrator.registerMigration("v3", migrate: migrateV3(database:))
        migrator.registerMigration("v4", migrate: migrateV4(database:))
        migrator.registerMigration("v5", migrate: migrateV5(database:))
    }

    static func migrateV1(database: Database) throws {
        // User profile
        try database.create(table: ProfileDB.databaseTableName) {
            $0.autoIncrementedPrimaryKey(ProfileDB.Columns.id.name)
            $0.column(ProfileDB.Columns.birthYear.name, .integer).notNull()
        }

        try database.create(table: NameDB.databaseTableName) {
            $0.primaryKey([NameDB.Columns.first.name, NameDB.Columns.last.name, NameDB.Columns.middle.name, NameDB.Columns.profileId.name])
            $0.foreignKey([NameDB.Columns.profileId.name], references: ProfileDB.databaseTableName)

            $0.column(NameDB.Columns.first.name, .text).notNull()
            $0.column(NameDB.Columns.last.name, .text).notNull()
            $0.column(NameDB.Columns.profileId.name, .integer).notNull()
            $0.column(NameDB.Columns.middle.name, .text)
            $0.column(NameDB.Columns.suffix.name, .text)
        }

        try database.create(table: AddressDB.databaseTableName) {
            $0.primaryKey([AddressDB.Columns.city.name, AddressDB.Columns.state.name, AddressDB.Columns.street.name, AddressDB.Columns.profileId.name])
            $0.foreignKey([AddressDB.Columns.profileId.name], references: ProfileDB.databaseTableName)

            $0.column(AddressDB.Columns.city.name, .text).notNull()
            $0.column(AddressDB.Columns.state.name, .text).notNull()
            $0.column(AddressDB.Columns.profileId.name, .integer).notNull()
            $0.column(AddressDB.Columns.street.name, .text)
            $0.column(AddressDB.Columns.zipCode.name, .text)
        }

        try database.create(table: PhoneDB.databaseTableName) {
            $0.primaryKey([PhoneDB.Columns.phoneNumber.name, PhoneDB.Columns.profileId.name])
            $0.foreignKey([PhoneDB.Columns.profileId.name], references: ProfileDB.databaseTableName)

            $0.column(PhoneDB.Columns.phoneNumber.name, .text).notNull()
            $0.column(PhoneDB.Columns.profileId.name, .integer).notNull()
        }

        // Operation and query related
        try database.create(table: ProfileQueryDB.databaseTableName) {
            $0.autoIncrementedPrimaryKey(ProfileQueryDB.Columns.id.name)
            $0.foreignKey([ProfileQueryDB.Columns.profileId.name], references: ProfileDB.databaseTableName)

            $0.column(ProfileQueryDB.Columns.profileId.name, .integer).notNull()
            $0.column(ProfileQueryDB.Columns.first.name, .text).notNull()
            $0.column(ProfileQueryDB.Columns.last.name, .text).notNull()
            $0.column(ProfileQueryDB.Columns.middle.name, .text)
            $0.column(ProfileQueryDB.Columns.suffix.name, .text)

            $0.column(ProfileQueryDB.Columns.city.name, .text).notNull()
            $0.column(ProfileQueryDB.Columns.state.name, .text).notNull()
            $0.column(ProfileQueryDB.Columns.street.name, .text)
            $0.column(ProfileQueryDB.Columns.zipCode.name, .text)

            $0.column(ProfileQueryDB.Columns.phone.name, .text)
            $0.column(ProfileQueryDB.Columns.birthYear.name, .integer)

            $0.column(ProfileQueryDB.Columns.deprecated.name, .boolean).notNull().defaults(to: false)
        }

        try database.create(table: BrokerDB.databaseTableName) {
            $0.autoIncrementedPrimaryKey(BrokerDB.Columns.id.name)

            $0.column(BrokerDB.Columns.name.name, .text).unique().notNull()
            $0.column(BrokerDB.Columns.json.name, .text).notNull()
            $0.column(BrokerDB.Columns.version.name, .text).notNull()
        }

        try database.create(table: ScanDB.databaseTableName) {
            $0.primaryKey([ScanDB.Columns.brokerId.name, ScanDB.Columns.profileQueryId.name])

            $0.foreignKey([ScanDB.Columns.brokerId.name], references: BrokerDB.databaseTableName)
            $0.foreignKey([ScanDB.Columns.profileQueryId.name],
                          references: ProfileQueryDB.databaseTableName,
                          onDelete: .cascade)

            $0.column(ScanDB.Columns.profileQueryId.name, .integer).notNull()
            $0.column(ScanDB.Columns.brokerId.name, .integer).notNull()
            $0.column(ScanDB.Columns.lastRunDate.name, .datetime)
            $0.column(ScanDB.Columns.preferredRunDate.name, .datetime)
        }

        try database.create(table: ScanHistoryEventDB.databaseTableName) {
            $0.primaryKey([
                ScanHistoryEventDB.Columns.brokerId.name,
                ScanHistoryEventDB.Columns.profileQueryId.name,
                ScanHistoryEventDB.Columns.event.name,
                ScanHistoryEventDB.Columns.timestamp.name
            ])

            $0.foreignKey([ScanDB.Columns.brokerId.name], references: BrokerDB.databaseTableName)
            $0.foreignKey([ScanDB.Columns.profileQueryId.name],
                          references: ProfileQueryDB.databaseTableName,
                          onDelete: .cascade)

            $0.column(ScanDB.Columns.profileQueryId.name, .integer).notNull()
            $0.column(ScanDB.Columns.brokerId.name, .integer).notNull()
            $0.column(ScanHistoryEventDB.Columns.event.name, .text).notNull()
            $0.column(ScanHistoryEventDB.Columns.timestamp.name, .datetime).notNull()
        }

        try database.create(table: ExtractedProfileDB.databaseTableName) {
            $0.autoIncrementedPrimaryKey(ExtractedProfileDB.Columns.id.name)

            $0.foreignKey([ExtractedProfileDB.Columns.brokerId.name], references: BrokerDB.databaseTableName)
            $0.foreignKey([ExtractedProfileDB.Columns.profileQueryId.name],
                          references: ProfileQueryDB.databaseTableName,
                          onDelete: .cascade)

            $0.column(ExtractedProfileDB.Columns.profileQueryId.name, .integer).notNull()
            $0.column(ExtractedProfileDB.Columns.brokerId.name, .integer).notNull()
            $0.column(ExtractedProfileDB.Columns.profile.name, .text).notNull()
            $0.column(ExtractedProfileDB.Columns.removedDate.name, .datetime)
        }

        try database.create(table: OptOutDB.databaseTableName) {
            $0.primaryKey([
                OptOutDB.Columns.profileQueryId.name,
                OptOutDB.Columns.brokerId.name,
                OptOutDB.Columns.extractedProfileId.name
            ])

            $0.foreignKey([OptOutDB.Columns.brokerId.name], references: BrokerDB.databaseTableName)
            $0.foreignKey([OptOutDB.Columns.profileQueryId.name],
                          references: ProfileQueryDB.databaseTableName,
                          onDelete: .cascade)

            $0.foreignKey([OptOutDB.Columns.extractedProfileId.name],
                          references: ExtractedProfileDB.databaseTableName,
                          onDelete: .cascade)

            $0.column(OptOutDB.Columns.profileQueryId.name, .integer).notNull()
            $0.column(OptOutDB.Columns.brokerId.name, .integer).notNull()
            $0.column(OptOutDB.Columns.extractedProfileId.name, .integer).notNull()
            $0.column(OptOutDB.Columns.lastRunDate.name, .datetime)
            $0.column(OptOutDB.Columns.preferredRunDate.name, .datetime)
        }

        try database.create(table: OptOutHistoryEventDB.databaseTableName) {
            $0.primaryKey([
                OptOutHistoryEventDB.Columns.profileQueryId.name,
                OptOutHistoryEventDB.Columns.brokerId.name,
                OptOutHistoryEventDB.Columns.extractedProfileId.name,
                OptOutHistoryEventDB.Columns.event.name,
                OptOutHistoryEventDB.Columns.timestamp.name
            ])

            $0.foreignKey([OptOutHistoryEventDB.Columns.brokerId.name], references: BrokerDB.databaseTableName)
            $0.foreignKey([OptOutHistoryEventDB.Columns.profileQueryId.name],
                          references: ProfileQueryDB.databaseTableName,
                          onDelete: .cascade)

            $0.column(OptOutHistoryEventDB.Columns.profileQueryId.name, .integer).notNull()
            $0.column(OptOutHistoryEventDB.Columns.brokerId.name, .integer).notNull()
            $0.column(OptOutHistoryEventDB.Columns.extractedProfileId.name, .integer).notNull()
            $0.column(OptOutHistoryEventDB.Columns.event.name, .text).notNull()
            $0.column(OptOutHistoryEventDB.Columns.timestamp.name, .datetime).notNull()
        }

        try database.create(table: OptOutAttemptDB.databaseTableName) {
            $0.primaryKey([OptOutAttemptDB.Columns.extractedProfileId.name])

            $0.foreignKey([OptOutAttemptDB.Columns.extractedProfileId.name], references: ExtractedProfileDB.databaseTableName)

            $0.column(OptOutAttemptDB.Columns.extractedProfileId.name, .integer).notNull()
            $0.column(OptOutAttemptDB.Columns.dataBroker.name, .text).notNull()
            $0.column(OptOutAttemptDB.Columns.attemptId.name, .text).notNull()
            $0.column(OptOutAttemptDB.Columns.lastStageDate.name, .date).notNull()
            $0.column(OptOutAttemptDB.Columns.startDate.name, .date).notNull()
        }
    }

    static func migrateV2(database: Database) throws {
        try database.alter(table: BrokerDB.databaseTableName) {
            $0.add(column: BrokerDB.Columns.url.name, .text)
        }
        try database.execute(sql: """
                UPDATE \(BrokerDB.databaseTableName) SET \(BrokerDB.Columns.url.name) = \(BrokerDB.Columns.name.name)
            """)
    }

    static func migrateV3(database: Database) throws {
        // Delete orphaned records
        try deleteOrphanedRecords(database: database)
        // Recreate tables to add correct foreign key constraints
        try recreateTablesV3(database: database)

        // As a precaution, re-run orphan deletion if necessary
        do {
            // Throws an error if a foreign key violation exists in the database.
            try database.checkForeignKeys()
        } catch {
            try deleteOrphanedRecords(database: database)
        }

        // Finally, if there are still integrity issues, throw a specific error
        do {
            // Throws an error if a foreign key violation exists in the database.
            try database.checkForeignKeys()
        } catch {
            throw DataBrokerProtectionDatabaseMigrationErrors.foreignKeyViolation
        }
    }

    static func migrateV4(database: Database) throws {
        try database.alter(table: OptOutDB.databaseTableName) {
            // We default `createdDate` values to unix epoch to avoid any existing data being treated as new data
            $0.add(column: OptOutDB.Columns.createdDate.name, .datetime).notNull().defaults(to: Date(timeIntervalSince1970: 0))

            // For existing data this will be nil even for opt outs that have been submitted
            $0.add(column: OptOutDB.Columns.submittedSuccessfullyDate.name, .datetime)

            $0.add(column: OptOutDB.Columns.sevenDaysConfirmationPixelFired.name, .boolean).notNull().defaults(to: false)
            $0.add(column: OptOutDB.Columns.fourteenDaysConfirmationPixelFired.name, .boolean).notNull().defaults(to: false)
            $0.add(column: OptOutDB.Columns.twentyOneDaysConfirmationPixelFired.name, .boolean).notNull().defaults(to: false)
        }
    }

    static func migrateV5(database: Database) throws {
        try database.alter(table: OptOutDB.databaseTableName) {
            // Keep track of opt-out request attempts
            $0.add(column: OptOutDB.Columns.attemptCount.name, .integer).notNull().defaults(to: 0)
        }
        try database.execute(sql: """
                UPDATE \(OptOutDB.databaseTableName) SET \(OptOutDB.Columns.attemptCount.name) = 0
        """)
    }

    private static func deleteOrphanedRecords(database: Database) throws {

        /*
         Cleanup strategy:
             1.    Root Nodes: Clean the tables that do not depend on any other tables but have dependencies.
             2.    Intermediate Nodes: Clean the tables that depend on root tables and have their own dependencies.
             3.    Leaf Nodes: Finally, clean the tables that do not have any other dependent tables.
         Cleanup order:
             1.    ProfileQueryDB
             2.    ExtractedProfileDB
             3.    ScanDB
             4.    OptOutDB
             5.    OptOutHistoryEventDB
             6.    ScanHistoryEventDB
             7.    OptOutAttemptDB
             8.    NameDB
             9.    AddressDB
             10.   PhoneDB
         */

        var deleteStatements: [String] = []

        // This deletion order should ensure that no foreign key violations remain
        deleteStatements.append(sqlOrphanedCleanupFromProfile(of: ProfileQueryDB.databaseTableName))
        deleteStatements.append(sqlOrphanedCleanupFromBrokerAndQuery(of: ExtractedProfileDB.databaseTableName))

        deleteStatements.append(sqlOrphanedCleanupFromBrokerAndQuery(of: ScanDB.databaseTableName))
        deleteStatements.append(sqlOrphanedCleanupFromBrokerAndQueryAndExtracted(of: OptOutDB.databaseTableName))

        deleteStatements.append(sqlOrphanedCleanupFromBrokerAndQueryAndExtracted(of: OptOutHistoryEventDB.databaseTableName))
        deleteStatements.append(sqlOrphanedCleanupFromBrokerAndQuery(of: ScanHistoryEventDB.databaseTableName))
        deleteStatements.append(sqlOrphanedCleanupFromExtracted(of: OptOutAttemptDB.databaseTableName))

        deleteStatements.append(sqlOrphanedCleanupFromProfile(of: NameDB.databaseTableName))
        deleteStatements.append(sqlOrphanedCleanupFromProfile(of: AddressDB.databaseTableName))
        deleteStatements.append(sqlOrphanedCleanupFromProfile(of: PhoneDB.databaseTableName))

        do {
            for sql in deleteStatements {
                try database.execute(sql: sql)
            }
        } catch {
            throw DataBrokerProtectionDatabaseMigrationErrors.deleteOrphanedRecordFailed
        }

        // As a precaution, explicitly check for any foreign key violations which were missed
        do {
            let recordCursor = try database.foreignKeyViolations()
            try recordCursor.forEach { violation in
                guard let originRowId = violation.originRowID else { return }
                let sql = sqlDelete(from: violation.originTable, id: String(originRowId))
                try database.execute(sql: sql, arguments: [violation.originRowID])
            }
        } catch {
            Logger.dataBrokerProtection.error("Database error: error cleaning up foreign key violations, error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func sqlOrphanedCleanupFromBrokerAndQueryAndExtracted(of table: String) -> String {
        """
        DELETE FROM \(table)
        WHERE NOT EXISTS (
            SELECT 1 FROM \(BrokerDB.databaseTableName)
            WHERE \(BrokerDB.databaseTableName).id = \(table).brokerId
        )
        OR NOT EXISTS (
            SELECT 1 FROM \(ProfileQueryDB.databaseTableName)
            WHERE \(ProfileQueryDB.databaseTableName).id = \(table).profileQueryId
        )
        OR NOT EXISTS (
            SELECT 1 FROM \(ExtractedProfileDB.databaseTableName)
            WHERE \(ExtractedProfileDB.databaseTableName).id = \(table).extractedProfileId
        )
        """
    }

    private static func sqlOrphanedCleanupFromBrokerAndQuery(of table: String) -> String {
        """
        DELETE FROM \(table)
        WHERE NOT EXISTS (
            SELECT 1 FROM \(BrokerDB.databaseTableName)
            WHERE \(BrokerDB.databaseTableName).id = \(table).brokerId
        )
        OR NOT EXISTS (
            SELECT 1 FROM \(ProfileQueryDB.databaseTableName)
            WHERE \(ProfileQueryDB.databaseTableName).id = \(table).profileQueryId
        )
        """
    }

    private static func sqlOrphanedCleanupFromExtracted(of table: String) -> String {
        """
        DELETE FROM \(table)
        WHERE NOT EXISTS (
            SELECT 1 FROM \(ExtractedProfileDB.databaseTableName)
            WHERE \(ExtractedProfileDB.databaseTableName).id = \(table).extractedProfileId
        )
        """
    }

    private static func sqlOrphanedCleanupFromProfile(of table: String) -> String {
        """
        DELETE FROM \(table)
        WHERE NOT EXISTS (
            SELECT 1 FROM \(ProfileDB.databaseTableName)
            WHERE \(ProfileDB.databaseTableName).id = \(table).profileId
        )
        """
    }

    private static func sqlDelete(from table: String, id: String) -> String {
        """
        DELETE FROM \(table)
        WHERE rowid = ?
        """
    }

    private static func recreateTablesV3(database: Database) throws {
        do {
            try recreateNameTable(database: database)
            try recreateAddressTable(database: database)
            try recreatePhoneTable(database: database)
            try recreateProfileQueryTable(database: database)
            try recreateScanTable(database: database)
            try recreateScanHistoryTable(database: database)
            try recreateExtractedProfileTable(database: database)
            try recreateOptOutTable(database: database)
            try recreateOptOutHistoryTable(database: database)
            try recreateOptOutAttemptTable(database: database)
        } catch {
            throw DataBrokerProtectionDatabaseMigrationErrors.recreateTablesFailed
        }
    }

    private static func recreateNameTable(database: Database) throws {
        try recreateTable(name: NameDB.databaseTableName, database: database) {
            try database.create(table: NameDB.databaseTableName) {
                $0.primaryKey([NameDB.Columns.first.name, NameDB.Columns.last.name, NameDB.Columns.middle.name, NameDB.Columns.profileId.name])
                $0.foreignKey([NameDB.Columns.profileId.name],
                              references: ProfileDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(NameDB.Columns.first.name, .text).notNull()
                $0.column(NameDB.Columns.last.name, .text).notNull()
                $0.column(NameDB.Columns.profileId.name, .integer).notNull()
                $0.column(NameDB.Columns.middle.name, .text)
                $0.column(NameDB.Columns.suffix.name, .text)
            }
        }
    }

    private static func recreateAddressTable(database: Database) throws {
        try recreateTable(name: AddressDB.databaseTableName, database: database) {
            try database.create(table: AddressDB.databaseTableName) {
                $0.primaryKey([AddressDB.Columns.city.name, AddressDB.Columns.state.name, AddressDB.Columns.street.name, AddressDB.Columns.profileId.name])
                $0.foreignKey([AddressDB.Columns.profileId.name],
                              references: ProfileDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(AddressDB.Columns.city.name, .text).notNull()
                $0.column(AddressDB.Columns.state.name, .text).notNull()
                $0.column(AddressDB.Columns.profileId.name, .integer).notNull()
                $0.column(AddressDB.Columns.street.name, .text)
                $0.column(AddressDB.Columns.zipCode.name, .text)
            }
        }
    }

    private static func recreatePhoneTable(database: Database) throws {
        try recreateTable(name: PhoneDB.databaseTableName, database: database) {
            try database.create(table: PhoneDB.databaseTableName) {
                $0.primaryKey([PhoneDB.Columns.phoneNumber.name, PhoneDB.Columns.profileId.name])
                $0.foreignKey([PhoneDB.Columns.profileId.name], references: ProfileDB.databaseTableName)

                $0.column(PhoneDB.Columns.phoneNumber.name, .text).notNull()
                $0.column(PhoneDB.Columns.profileId.name, .integer).notNull()
            }
        }
    }

    private static func recreateProfileQueryTable(database: Database) throws {
        try recreateTable(name: ProfileQueryDB.databaseTableName, database: database) {
            try database.create(table: ProfileQueryDB.databaseTableName) {
                $0.autoIncrementedPrimaryKey(ProfileQueryDB.Columns.id.name)
                $0.foreignKey([ProfileQueryDB.Columns.profileId.name],
                              references: ProfileDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(ProfileQueryDB.Columns.profileId.name, .integer).notNull()
                $0.column(ProfileQueryDB.Columns.first.name, .text).notNull()
                $0.column(ProfileQueryDB.Columns.last.name, .text).notNull()
                $0.column(ProfileQueryDB.Columns.middle.name, .text)
                $0.column(ProfileQueryDB.Columns.suffix.name, .text)

                $0.column(ProfileQueryDB.Columns.city.name, .text).notNull()
                $0.column(ProfileQueryDB.Columns.state.name, .text).notNull()
                $0.column(ProfileQueryDB.Columns.street.name, .text)
                $0.column(ProfileQueryDB.Columns.zipCode.name, .text)

                $0.column(ProfileQueryDB.Columns.phone.name, .text)
                $0.column(ProfileQueryDB.Columns.birthYear.name, .integer)

                $0.column(ProfileQueryDB.Columns.deprecated.name, .boolean).notNull().defaults(to: false)
            }
        }
    }

    private static func recreateScanTable(database: Database) throws {
        try recreateTable(name: ScanDB.databaseTableName, database: database) {
            try database.create(table: ScanDB.databaseTableName) {
                $0.primaryKey([ScanDB.Columns.brokerId.name, ScanDB.Columns.profileQueryId.name])

                $0.foreignKey([ScanDB.Columns.brokerId.name],
                              references: BrokerDB.databaseTableName,
                              onDelete: .cascade)
                $0.foreignKey([ScanDB.Columns.profileQueryId.name],
                              references: ProfileQueryDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(ScanDB.Columns.profileQueryId.name, .integer).notNull()
                $0.column(ScanDB.Columns.brokerId.name, .integer).notNull()
                $0.column(ScanDB.Columns.lastRunDate.name, .datetime)
                $0.column(ScanDB.Columns.preferredRunDate.name, .datetime)
            }
        }
    }

    private static func recreateScanHistoryTable(database: Database) throws {
        try recreateTable(name: ScanHistoryEventDB.databaseTableName, database: database) {
            try database.create(table: ScanHistoryEventDB.databaseTableName) {
                $0.primaryKey([
                    ScanHistoryEventDB.Columns.brokerId.name,
                    ScanHistoryEventDB.Columns.profileQueryId.name,
                    ScanHistoryEventDB.Columns.event.name,
                    ScanHistoryEventDB.Columns.timestamp.name
                ])

                $0.foreignKey([ScanDB.Columns.brokerId.name],
                              references: BrokerDB.databaseTableName,
                              onDelete: .cascade)
                $0.foreignKey([ScanDB.Columns.profileQueryId.name],
                              references: ProfileQueryDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(ScanDB.Columns.profileQueryId.name, .integer).notNull()
                $0.column(ScanDB.Columns.brokerId.name, .integer).notNull()
                $0.column(ScanHistoryEventDB.Columns.event.name, .text).notNull()
                $0.column(ScanHistoryEventDB.Columns.timestamp.name, .datetime).notNull()
            }
        }
    }

    private static func recreateExtractedProfileTable(database: Database) throws {
        try recreateTable(name: ExtractedProfileDB.databaseTableName, database: database) {
            try database.create(table: ExtractedProfileDB.databaseTableName) {
                $0.autoIncrementedPrimaryKey(ExtractedProfileDB.Columns.id.name)

                $0.foreignKey([ExtractedProfileDB.Columns.brokerId.name],
                              references: BrokerDB.databaseTableName,
                              onDelete: .cascade)
                $0.foreignKey([ExtractedProfileDB.Columns.profileQueryId.name],
                              references: ProfileQueryDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(ExtractedProfileDB.Columns.profileQueryId.name, .integer).notNull()
                $0.column(ExtractedProfileDB.Columns.brokerId.name, .integer).notNull()
                $0.column(ExtractedProfileDB.Columns.profile.name, .text).notNull()
                $0.column(ExtractedProfileDB.Columns.removedDate.name, .datetime)
            }
        }
    }

    private static func recreateOptOutTable(database: Database) throws {
        try recreateTable(name: OptOutDB.databaseTableName, database: database) {
            try database.create(table: OptOutDB.databaseTableName) {
                $0.primaryKey([
                    OptOutDB.Columns.profileQueryId.name,
                    OptOutDB.Columns.brokerId.name,
                    OptOutDB.Columns.extractedProfileId.name
                ])

                $0.foreignKey([OptOutDB.Columns.brokerId.name],
                              references: BrokerDB.databaseTableName,
                              onDelete: .cascade)
                $0.foreignKey([OptOutDB.Columns.profileQueryId.name],
                              references: ProfileQueryDB.databaseTableName,
                              onDelete: .cascade)
                $0.foreignKey([OptOutDB.Columns.extractedProfileId.name],
                              references: ExtractedProfileDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(OptOutDB.Columns.profileQueryId.name, .integer).notNull()
                $0.column(OptOutDB.Columns.brokerId.name, .integer).notNull()
                $0.column(OptOutDB.Columns.extractedProfileId.name, .integer).notNull()
                $0.column(OptOutDB.Columns.lastRunDate.name, .datetime)
                $0.column(OptOutDB.Columns.preferredRunDate.name, .datetime)
            }
        }
    }

    private static func recreateOptOutHistoryTable(database: Database) throws {
        try recreateTable(name: OptOutHistoryEventDB.databaseTableName, database: database) {
            try database.create(table: OptOutHistoryEventDB.databaseTableName) {
                $0.primaryKey([
                    OptOutHistoryEventDB.Columns.profileQueryId.name,
                    OptOutHistoryEventDB.Columns.brokerId.name,
                    OptOutHistoryEventDB.Columns.extractedProfileId.name,
                    OptOutHistoryEventDB.Columns.event.name,
                    OptOutHistoryEventDB.Columns.timestamp.name
                ])

                $0.foreignKey([OptOutHistoryEventDB.Columns.brokerId.name],
                              references: BrokerDB.databaseTableName,
                              onDelete: .cascade)
                $0.foreignKey([OptOutHistoryEventDB.Columns.profileQueryId.name],
                              references: ProfileQueryDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(OptOutHistoryEventDB.Columns.profileQueryId.name, .integer).notNull()
                $0.column(OptOutHistoryEventDB.Columns.brokerId.name, .integer).notNull()
                $0.column(OptOutHistoryEventDB.Columns.extractedProfileId.name, .integer).notNull()
                $0.column(OptOutHistoryEventDB.Columns.event.name, .text).notNull()
                $0.column(OptOutHistoryEventDB.Columns.timestamp.name, .datetime).notNull()
            }
        }
    }

    private static func recreateOptOutAttemptTable(database: Database) throws {
        try recreateTable(name: OptOutAttemptDB.databaseTableName, database: database) {
            try database.create(table: OptOutAttemptDB.databaseTableName) {
                $0.primaryKey([OptOutAttemptDB.Columns.extractedProfileId.name])

                $0.foreignKey([OptOutAttemptDB.Columns.extractedProfileId.name],
                              references: ExtractedProfileDB.databaseTableName,
                              onDelete: .cascade)

                $0.column(OptOutAttemptDB.Columns.extractedProfileId.name, .integer).notNull()
                $0.column(OptOutAttemptDB.Columns.dataBroker.name, .text).notNull()
                $0.column(OptOutAttemptDB.Columns.attemptId.name, .text).notNull()
                $0.column(OptOutAttemptDB.Columns.lastStageDate.name, .date).notNull()
                $0.column(OptOutAttemptDB.Columns.startDate.name, .date).notNull()
            }
        }
    }

    /// Recreates the specified table
    /// - Parameters:
    ///   - name: Table to recreate
    ///   - database: Database to use
    ///   - creationActions: Actions to perform as first step in the table creation process
    private static func recreateTable(name: String,
                                      database: Database,
                                      creationActions: () throws -> Void) throws {
        try database.rename(table: name,
                            to: name + "Old")

        try creationActions()

        try database.execute(sql: """
            INSERT INTO \(name) SELECT * FROM \(name + "Old")
            """)

        try database.drop(table: name + "Old")
    }
}
