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
    func saveProfile(profile: ProfileDB) throws -> Int64
    func fetchProfile(with id: Int64) throws -> ProfileDB?
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

            $0.column(ProfileDB.Columns.firstName.name, .blob).notNull()
            $0.column(ProfileDB.Columns.lastName.name, .blob).notNull()
            $0.column(ProfileDB.Columns.city.name, .blob).notNull()
            $0.column(ProfileDB.Columns.state.name, .blob).notNull()
            $0.column(ProfileDB.Columns.age.name, .blob).notNull()
        }
    }

    func saveProfile(profile: ProfileDB) throws -> Int64 {
        try db.write { db in
            if profile.id == nil {
                try profile.insert(db)
            } else {
                try profile.update(db)
            }

            return 1 // We return 1 because (for testing purposes) we are only working with the first profile
        }
    }

    func fetchProfile(with id: Int64) throws -> ProfileDB? {
        try db.read({ database in
            let profile = try ProfileDB.fetchOne(database)

            return profile
        })
    }
}
