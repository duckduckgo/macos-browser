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
 }

final class DefaultDataBrokerProtectionDatabaseProvider: GRDBSecureStorageDatabaseProvider, DataBrokerProtectionDatabaseProvider {

    public static func defaultDatabaseURL() -> URL {
        return DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: "DBP", fileName: "Vault.db", appGroupIdentifier: Bundle.main.appGroupName)
    }

    public init(file: URL = DefaultDataBrokerProtectionDatabaseProvider.defaultDatabaseURL(), key: Data) throws {
        try super.init(file: file, key: key, writerType: .pool) { migrator in
            migrator.registerMigration("v1", migrate: Self.migrateV1(database:))
            migrator.registerMigration("v2", migrate: Self.migrateV2(database:))
            migrator.registerMigration("v3", migrate: Self.migrateV3(database:))

        }
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

        // Clean up data
        try deleteOrphanedRecords(database: database)

        // Recreate Tables
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
    }

    static func deleteOrphanedRecords(database: Database) throws {

        let missingProfileIdDelete: (String) -> String = { tableName in
                            """
                            DELETE FROM \(tableName)
                            WHERE profileId NOT IN (
                                SELECT id FROM \(ProfileDB.databaseTableName)
                            )
                            """
        }

        let missingProfileAndBrokerIdDelete: (String) -> String = { tableName in
                                         """
                                         DELETE FROM \(tableName)
                                         WHERE profileQueryId NOT IN (
                                             SELECT id FROM \(ProfileQueryDB.databaseTableName)
                                         ) OR brokerId NOT IN (
                                             SELECT id FROM \(BrokerDB.databaseTableName)
                                         )
                                         """
        }

        let deleteStatements = [
                """
                DELETE FROM \(OptOutHistoryEventDB.databaseTableName)
                WHERE (profileQueryId, brokerId, extractedProfileId) NOT IN (
                    SELECT profileQueryId, brokerId, extractedProfileId FROM \(OptOutDB.databaseTableName)
                )
                """,
                """
                DELETE FROM \(OptOutDB.databaseTableName)
                WHERE profileQueryId NOT IN (
                    SELECT id FROM \(ProfileQueryDB.databaseTableName)
                ) OR brokerId NOT IN (
                    SELECT id FROM \(BrokerDB.databaseTableName)
                ) OR extractedProfileId NOT IN (
                    SELECT id FROM \(ExtractedProfileDB.databaseTableName)
                )
                """,
                """
                \(missingProfileAndBrokerIdDelete(ScanHistoryEventDB.databaseTableName))
                """,
                """
                \(missingProfileAndBrokerIdDelete(ScanDB.databaseTableName))
                """,
                """
                DELETE FROM \(OptOutAttemptDB.databaseTableName)
                WHERE extractedProfileId NOT IN (
                    SELECT id FROM \(ExtractedProfileDB.databaseTableName)
                )
                """,
                """
                \(missingProfileAndBrokerIdDelete(ExtractedProfileDB.databaseTableName))
                """,
                """
                \(missingProfileIdDelete(ProfileQueryDB.databaseTableName))
                """,
                """
                \(missingProfileIdDelete(NameDB.databaseTableName))
                """,
                """
                \(missingProfileIdDelete(AddressDB.databaseTableName))
                """,
                """
                \(missingProfileIdDelete(PhoneDB.databaseTableName))
                """
        ]

        for sql in deleteStatements {
            try database.execute(sql: sql)
        }

    }

    static func recreateNameTable(database: Database) throws {
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

    static func recreateAddressTable(database: Database) throws {
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

    static func recreatePhoneTable(database: Database) throws {
        try recreateTable(name: PhoneDB.databaseTableName, database: database) {
            try database.create(table: PhoneDB.databaseTableName) {
                $0.primaryKey([PhoneDB.Columns.phoneNumber.name, PhoneDB.Columns.profileId.name])
                $0.foreignKey([PhoneDB.Columns.profileId.name], references: ProfileDB.databaseTableName)

                $0.column(PhoneDB.Columns.phoneNumber.name, .text).notNull()
                $0.column(PhoneDB.Columns.profileId.name, .integer).notNull()
            }
        }
    }

    static func recreateProfileQueryTable(database: Database) throws {
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

    static func recreateScanTable(database: Database) throws {
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

    static func recreateScanHistoryTable(database: Database) throws {
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

    static func recreateExtractedProfileTable(database: Database) throws {
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

    static func recreateOptOutTable(database: Database) throws {
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

    static func recreateOptOutHistoryTable(database: Database) throws {
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

    static func recreateOptOutAttemptTable(database: Database) throws {
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

    static func recreateTable(name: String,
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
