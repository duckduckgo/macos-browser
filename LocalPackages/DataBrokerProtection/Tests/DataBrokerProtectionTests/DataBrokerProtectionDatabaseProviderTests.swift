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
@testable import DataBrokerProtection

final class DataBrokerProtectionDatabaseProviderTests: XCTestCase {

    private var sut: DataBrokerProtectionDatabaseProvider!
    private let vaultURL = DefaultDataBrokerProtectionDatabaseProvider.databaseFilePath(directoryName: "DBP", fileName: "Test-Vault.db")
    private let key = "9CA59EDC-5CE8-4F53-AAC6-286A7378F384".data(using: .utf8)!

    override func setUpWithError() throws {

        do {
            sut = try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key)
            let fileURL = Bundle.module.url(forResource: "test-vault", withExtension: "sql")!
            try sut.restoreDatabase(from: fileURL)
        } catch {
            XCTFail("Failed to create vault and insert data")
        }
    }

    override func tearDownWithError() throws {
        let fileManager = FileManager.default

            // Check if file exists
            if fileManager.fileExists(atPath: vaultURL.path) {
                do {
                    // Delete the file
                    try fileManager.removeItem(at: vaultURL)
                    print("File deleted successfully.")
                } catch let error as NSError {
                    // Handle error
                    print("Error deleting file: \(error.localizedDescription)")
                }
            } else {
                print("File does not exist at \(vaultURL.path)")
            }
    }

    func testExample() throws {
        sut = try DefaultDataBrokerProtectionDatabaseProvider(file: vaultURL, key: key, registerMigrationsHandler: Migrations.v3Migrations)
    }
}
