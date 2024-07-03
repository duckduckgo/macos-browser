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

final class CSVImporterIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testImportPasswordsPerformance() async throws {
        let csvURL = Bundle(for: Self.self).url(forResource: "mock_login_data_large", withExtension: "csv")!
        let csvImporter = CSVImporter(
            fileURL: csvURL,
            loginImporter: SecureVaultLoginImporter(),
            defaultColumnPositions: nil
        )
        let importTask = csvImporter.importData(types: [.passwords])

        // No baseline set, but should be no more than 0.3 seconds on an M1 Max with 32GB memory
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
}
