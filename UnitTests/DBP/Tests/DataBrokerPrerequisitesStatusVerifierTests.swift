//
//  DataBrokerPrerequisitesStatusVerifierTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
import DataBrokerProtection

final class DataBrokerPrerequisitesStatusVerifierTests: XCTestCase {
    private let statusChecker = MockDBPLoginItemStatusChecker()

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        statusChecker.reset()
    }

    func testIncorrectDirectory_thenReturnIncorrectDirectoryStatus() {
        statusChecker.isInCorrectDirectoryValue = false
        let result = DefaultDataBrokerPrerequisitesStatusVerifier(statusChecker: statusChecker).checkStatus()
        XCTAssertEqual(result, DataBrokerPrerequisitesStatus.invalidDirectory)
    }

    func testIncorrectPermission_thenReturnIncorrectPermissionStatus() {
        statusChecker.doesHavePermissionValue = false
        let result = DefaultDataBrokerPrerequisitesStatusVerifier(statusChecker: statusChecker).checkStatus()
        XCTAssertEqual(result, DataBrokerPrerequisitesStatus.invalidSystemPermission)
    }

    func testIncorrectDirectoryAndIncorrectPermission_thenReturnIncorrectPermissionStatus() {
        statusChecker.isInCorrectDirectoryValue = false
        statusChecker.doesHavePermissionValue = false
        let result = DefaultDataBrokerPrerequisitesStatusVerifier(statusChecker: statusChecker).checkStatus()
        XCTAssertEqual(result, DataBrokerPrerequisitesStatus.invalidSystemPermission)
    }

    func testCorrectStatus_thenReturnValidStatus() {
        let result = DefaultDataBrokerPrerequisitesStatusVerifier(statusChecker: statusChecker).checkStatus()
        XCTAssertEqual(result, DataBrokerPrerequisitesStatus.valid)
    }
}

private final class MockDBPLoginItemStatusChecker: DBPLoginItemStatusChecker {
    var doesHavePermissionValue = true
    var isInCorrectDirectoryValue = true

    func doesHaveNecessaryPermissions() -> Bool {
        return doesHavePermissionValue
    }
    func isInCorrectDirectory() -> Bool {
        return isInCorrectDirectoryValue
    }

    func reset() {
        doesHavePermissionValue = true
        isInCorrectDirectoryValue = true
    }
}
