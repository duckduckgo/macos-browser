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

final class DataBrokerProtectionDatabaseProviderTests: XCTestCase {

    private var sut: DataBrokerProtectionDatabaseProvider!
    private let vaultURL = DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: "DBP", fileName: "Test-Vault.db")
    private let key = "9CA59EDC-5CE8-4F53-AAC6-286A7378F384".data(using: .utf8)!

    override func setUpWithError() throws {
        do {
            // Sets up a test vault and restores data (with violations) from a `test-vault.sql` file
            sut = try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key)
            let fileURL = Bundle.module.url(forResource: "test-vault", withExtension: "sql")!
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
    }

    func testV3MigrationCleansUpOrphanedRecordsAndSucceeds() throws {
        // Given
        let failingMigration: (inout DatabaseMigrator) throws -> Void = { migrator in
            migrator.registerMigration("v3") { database in
                // This failing migration is used to ensure the database contains violations
                try database.checkForeignKeys()
            }
        }
        XCTAssertThrowsError(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: failingMigration))

        // When - Then
        XCTAssertNoThrow(try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v3Migrations))
    }
}
