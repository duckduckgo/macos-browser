//
//  ApplicationUpdateDetectorTests.swift
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

import BrowserServicesKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class ApplicationUpdateDetectorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset the state before each test
        ApplicationUpdateDetector.resetState()
    }

    func testIsApplicationUpdated_noChange() {
        let status = ApplicationUpdateDetector.isApplicationUpdated(currentVersion: "1.0", currentBuild: "1", previousVersion: "1.0", previousBuild: "1")

        XCTAssertEqual(status, .noChange, "Expected noChange when version and build are the same")
    }

    func testIsApplicationUpdated_updatedVersion() {
        let status = ApplicationUpdateDetector.isApplicationUpdated(currentVersion: "2.0", currentBuild: "1", previousVersion: "1.0", previousBuild: "1")

        XCTAssertEqual(status, .updated, "Expected updated when version is newer")
    }

    func testIsApplicationUpdated_downgradedVersion() {
        let status = ApplicationUpdateDetector.isApplicationUpdated(currentVersion: "1.0", currentBuild: "1", previousVersion: "2.0", previousBuild: "1")

        XCTAssertEqual(status, .downgraded, "Expected downgraded when version is older")
    }

    func testIsApplicationUpdated_updatedBuild() {
        let status = ApplicationUpdateDetector.isApplicationUpdated(currentVersion: "1.0", currentBuild: "2", previousVersion: "1.0", previousBuild: "1")

        XCTAssertEqual(status, .updated, "Expected updated when build is newer")
    }

    func testIsApplicationUpdated_downgradedBuild() {
        let status = ApplicationUpdateDetector.isApplicationUpdated(currentVersion: "1.0", currentBuild: "1", previousVersion: "1.0", previousBuild: "2")

        XCTAssertEqual(status, .downgraded, "Expected downgraded when build is older")
    }
}
