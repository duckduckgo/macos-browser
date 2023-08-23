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

protocol DataBrokerProtectionDatabaseProvider: SecureStorageDatabaseProvider {
    func saveProfile(profile: DataBrokerProtectionProfile, mapperToDB: MapperToDB) throws -> Int64
    func fetchProfile(with id: Int64) throws -> FullProfileDB?
}

final class DefaultDataBrokerProtectionDatabaseProvider: GRDBSecureStorageDatabaseProvider, DataBrokerProtectionDatabaseProvider {

    public static func defaultDatabaseURL() -> URL {
        return DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: "DBP", fileName: "Vault.db")
    }

    public init(file: URL = DefaultDataBrokerProtectionDatabaseProvider.defaultDatabaseURL(), key: Data) throws {
        try super.init(file: file, key: key, writerType: .queue) { migrator in
            migrator.registerMigration("v1", migrate: Self.migrateV1(database:))
        }
    }

    // swiftlint:disable function_body_length
    static func migrateV1(database: Database) throws {
        // User profile
        try database.create(table: ProfileDB.databaseTableName) {
            $0.autoIncrementedPrimaryKey(ProfileDB.Columns.id.name)
            $0.column(ProfileDB.Columns.age.name, .integer).notNull()
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
            $0.column(ProfileQueryDB.Columns.age.name, .integer)
        }

        try database.create(table: BrokerDB.databaseTableName) {
            $0.autoIncrementedPrimaryKey(BrokerDB.Columns.id.name)

            $0.column(BrokerDB.Columns.name.name, .text).unique().notNull()
            $0.column(BrokerDB.Columns.json.name, .text).notNull()
            $0.column(BrokerDB.Columns.version.name, .numeric).notNull()
        }

        try database.create(table: ScanDB.databaseTableName) {
            $0.primaryKey([ScanDB.Columns.brokerId.name, ScanDB.Columns.profileQueryId.name])

            $0.foreignKey([ScanDB.Columns.brokerId.name], references: BrokerDB.databaseTableName)
            $0.foreignKey([ScanDB.Columns.profileQueryId.name], references: ProfileQueryDB.databaseTableName)

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
            $0.foreignKey([ScanDB.Columns.profileQueryId.name], references: ProfileQueryDB.databaseTableName)

            $0.column(ScanDB.Columns.profileQueryId.name, .integer).notNull()
            $0.column(ScanDB.Columns.brokerId.name, .integer).notNull()
            $0.column(ScanHistoryEventDB.Columns.event.name, .text).notNull()
            $0.column(ScanHistoryEventDB.Columns.timestamp.name, .datetime).notNull()
        }

        try database.create(table: ExtractedProfileDB.databaseTableName) {
            $0.autoIncrementedPrimaryKey(ExtractedProfileDB.Columns.id.name)

            $0.foreignKey([ExtractedProfileDB.Columns.brokerId.name], references: BrokerDB.databaseTableName)
            $0.foreignKey([ExtractedProfileDB.Columns.profileQueryId.name], references: ProfileQueryDB.databaseTableName)

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
            $0.foreignKey([OptOutDB.Columns.profileQueryId.name], references: ProfileQueryDB.databaseTableName)
            $0.foreignKey([OptOutDB.Columns.extractedProfileId.name], references: ExtractedProfileDB.databaseTableName)

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

            $0.column(OptOutHistoryEventDB.Columns.profileQueryId.name, .integer).notNull()
            $0.column(OptOutHistoryEventDB.Columns.brokerId.name, .integer).notNull()
            $0.column(OptOutHistoryEventDB.Columns.extractedProfileId.name, .integer).notNull()
            $0.column(OptOutHistoryEventDB.Columns.event.name, .text).notNull()
            $0.column(OptOutHistoryEventDB.Columns.timestamp.name, .datetime).notNull()
        }
    }
    // swiftlint:enable function_body_length

    func saveProfile(profile: DataBrokerProtectionProfile, mapperToDB: MapperToDB) throws -> Int64 {
        try db.write { db in
            try mapperToDB.mapToDB(profile: profile).insert(db)
            let profileId = db.lastInsertedRowID

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
}
