//
//  MapperToModelTests.swift
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

import XCTest
@testable import DataBrokerProtection

final class MapperToModelTests: XCTestCase {

    private var sut = MapperToModel(mechanism: {_ in Data()})
    private var jsonDecoder: JSONDecoder!
    private var jsonEncoder: JSONEncoder!

    override func setUpWithError() throws {
        jsonDecoder = JSONDecoder()
        jsonEncoder = JSONEncoder()
    }

    func testMapToModel_validData() throws {
        // Given
        let brokerData = DataBroker(
            id: 1,
            name: "TestBroker",
            url: "https://example.com",
            steps: [],
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 2, maintenanceScan: 3, maxAttempts: -1),
            parent: "ParentBroker",
            mirrorSites: [],
            optOutUrl: "https://example.com/opt-out"
        )
        let jsonData = try jsonEncoder.encode(brokerData)
        let brokerDB = BrokerDB(id: 1, name: "TestBroker", json: jsonData, version: "1.0", url: "https://example.com")

        // When
        let result = try sut.mapToModel(brokerDB)

        // Then
        XCTAssertEqual(result.id, brokerDB.id)
        XCTAssertEqual(result.name, brokerDB.name)
        XCTAssertEqual(result.url, brokerData.url)
        XCTAssertEqual(result.version, brokerData.version)
        XCTAssertEqual(result.steps.count, brokerData.steps.count)
        XCTAssertEqual(result.parent, brokerData.parent)
        XCTAssertEqual(result.mirrorSites.count, brokerData.mirrorSites.count)
        XCTAssertEqual(result.optOutUrl, brokerData.optOutUrl)
    }

    func testMapToModel_missingOptionalFields() throws {
        // Given
        let brokerData = """
            {
                "name": "TestBroker",
                "url": "https://example.com",
                "steps": [],
                "version": "1.0",
                "schedulingConfig": {"retryError": 1, "confirmOptOutScan": 2, "maintenanceScan": 3, "maxAttempts": -1}
            }
            """.data(using: .utf8)!
        let brokerDB = BrokerDB(id: 1, name: "TestBroker", json: brokerData, version: "1.0", url: "https://example.com")

        // When
        let result = try sut.mapToModel(brokerDB)

        // Then
        XCTAssertNil(result.parent)
        XCTAssertEqual(result.mirrorSites.count, 0)
        XCTAssertEqual(result.optOutUrl, "")
    }

    func testMapToModel_invalidJSONStructure() throws {
        // Given
        let invalidJsonData = """
            {
                "invalidKey": "value"
            }
            """.data(using: .utf8)!
        let brokerDB = BrokerDB(id: 1, name: "InvalidBroker", json: invalidJsonData, version: "1.0", url: "https://example.com")

        // When & Then
        XCTAssertThrowsError(try sut.mapToModel(brokerDB)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testMapToModel_missingUrlFallbackToName() throws {
        // Given
        let brokerData = """
            {
                "name": "TestBroker",
                "steps": [],
                "version": "1.0",
                "schedulingConfig": {"retryError": 1, "confirmOptOutScan": 2, "maintenanceScan": 3, "maxAttempts": -1}
            }
            """.data(using: .utf8)!
        let brokerDB = BrokerDB(id: 1, name: "TestBroker", json: brokerData, version: "1.0", url: "")

        // When
        let result = try sut.mapToModel(brokerDB)

        // Then
        XCTAssertEqual(result.url, brokerDB.name)
    }
}
