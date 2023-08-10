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

    static func migrateV1(database: Database) throws {
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
            $0.column(NameDB.Columns.profileId.name, .integer).notNull()
            $0.column(AddressDB.Columns.street.name, .text)
            $0.column(AddressDB.Columns.zipCode.name, .text)
        }

        try database.create(table: PhoneDB.databaseTableName) {
            $0.primaryKey([PhoneDB.Columns.phoneNumber.name, PhoneDB.Columns.profileId.name])
            $0.foreignKey([PhoneDB.Columns.profileId.name], references: ProfileDB.databaseTableName)

            $0.column(PhoneDB.Columns.phoneNumber.name, .text).notNull()
            $0.column(PhoneDB.Columns.profileId.name, .integer).notNull()
        }
    }

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
