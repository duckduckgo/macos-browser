//
//  FreemiumPIRUserStateManagerTests.swift
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
@testable import Freemium

final class FreemiumPIRUserStateManagerTests: XCTestCase {

    private enum Keys {
        static let didOnboard = "macos.browser.freemium.pir.did.onboard"
        static let firstProfileSavedTimestamp = "macos.browser.freemium.pir.profile.saved.timestamp"
    }

    private static let testSuiteName = "test.defaults.freemium.user.state.tests"
    private let testUserDefaults = UserDefaults(suiteName: FreemiumPIRUserStateManagerTests.testSuiteName)!

    override func setUpWithError() throws {
        testUserDefaults.removePersistentDomain(forName: FreemiumPIRUserStateManagerTests.testSuiteName)
    }

    func testSetsDidOnboard() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(testUserDefaults.bool(forKey: Keys.didOnboard))

        // When
        sut.didOnboard = true

        // Then
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didOnboard))
    }

    func testGetsDidOnboard() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(sut.didOnboard)
        testUserDefaults.setValue(true, forKey: Keys.didOnboard)
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didOnboard))

        // When
        let result = sut.didOnboard

        // Then
        XCTAssertTrue(result)
    }

    func testSetsfirstProfileSavedTimestamp() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertNil(testUserDefaults.value(forKey: Keys.firstProfileSavedTimestamp))

        // When
        sut.firstProfileSavedTimestamp = "time_stamp"

        // Then
        XCTAssertNotNil(testUserDefaults.value(forKey: Keys.firstProfileSavedTimestamp))
    }

    func testGetsfirstProfileSavedTimestamp() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertNil(sut.firstProfileSavedTimestamp)
        testUserDefaults.setValue("time_stamp", forKey: Keys.firstProfileSavedTimestamp)
        XCTAssertNotNil(testUserDefaults.value(forKey: Keys.firstProfileSavedTimestamp))

        // When
        let result = sut.firstProfileSavedTimestamp

        // Then
        XCTAssertNotNil(result)
    }
}
