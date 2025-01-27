//
//  CSVImporterIntegrationTests.swift
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
import XCTest
@testable import DuckDuckGo_Privacy_Browser
import BrowserServicesKit

final class CSVImporterIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? clearDB()
        executionTimeAllowance = 10
    }

    override func tearDown() {
        try? clearDB()
        super.tearDown()
    }

    func clearDB() throws {
        let vault = try AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared)

        let accounts = try vault.accounts()
        for accountID in accounts.compactMap(\.id) {
            if let accountID = Int64(accountID) {
                try vault.deleteWebsiteCredentialsFor(accountId: accountID)
            }
        }
    }

// Flakiness needs addressing
    func _testImportPasswordsPerformance() async throws {
        let csvURL = Bundle(for: Self.self).url(forResource: "mock_login_data_large", withExtension: "csv")!
        let csvImporter = CSVImporter(
            fileURL: csvURL,
            loginImporter: SecureVaultLoginImporter(),
            defaultColumnPositions: nil, reporter: SecureVaultReporter.shared
        )
        let importTask = csvImporter.importData(types: [.passwords])

        // No baseline set, but should be no more than 0.5 seconds on an M1 Max with 32GB memory
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let expectation = expectation(description: "Measure finished")
            Task {
                startMeasuring()
                let result = await importTask.result
                _ = try result.get()
                stopMeasuring()
                expectation.fulfill()
            }
            wait(for: [expectation])
        }
    }

    // Flakiness needs addressing
    // Deduplication rules: https://app.asana.com/0/0/1207598052765977/f
    func _testImportingPasswords_deduplicatesAccordingToDefinedRules() async throws {
        let startingDataURL = Bundle(for: Self.self).url(forResource: "login_deduplication_starting_data", withExtension: "csv")!
        let startingDataImporter = CSVImporter(
            fileURL: startingDataURL,
            loginImporter: SecureVaultLoginImporter(),
            defaultColumnPositions: nil, reporter: SecureVaultReporter.shared
        )
        _ = await startingDataImporter.importData(types: [.passwords]).result

        let testDataURL = Bundle(for: Self.self).url(forResource: "login_deduplication_test_data", withExtension: "csv")!
        let testDataImporter = CSVImporter(
            fileURL: testDataURL,
            loginImporter: SecureVaultLoginImporter(),
            defaultColumnPositions: nil, reporter: SecureVaultReporter.shared
        )
        let importTask = testDataImporter.importData(types: [.passwords])
        let result = await importTask.result
        let summary = try result.get()[.passwords]?.get()

        XCTAssertEqual(summary?.duplicate, 4)
    }
}
