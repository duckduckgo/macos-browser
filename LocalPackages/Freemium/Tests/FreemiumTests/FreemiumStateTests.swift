//
//  FreemiumStateTests.swift
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

final class FreemiumStateTests: XCTestCase {

    private static let testSuiteName = "test.defaults.freemium.state.tests"
    private let pir = "macos.browser.freemium.pir"
    private let testUserDefaults = UserDefaults(suiteName: FreemiumStateTests.testSuiteName)!

    override func setUpWithError() throws {
        testUserDefaults.removePersistentDomain(forName: FreemiumStateTests.testSuiteName)
    }

    func testSetsHasFreemiumPIR() throws {
        // Given
        let sut = DefaultFreemiumState(userDefaults: testUserDefaults)
        XCTAssertFalse(testUserDefaults.bool(forKey: pir))

        // When
        sut.hasFreemiumPIR = true

        // Then
        XCTAssertTrue(testUserDefaults.bool(forKey: pir))
    }

    func testGetsHasFreemiumPIR() throws {
        // Given
        let sut = DefaultFreemiumState(userDefaults: testUserDefaults)
        XCTAssertFalse(sut.hasFreemiumPIR)
        testUserDefaults.setValue(true, forKey: pir)
        XCTAssertTrue(testUserDefaults.bool(forKey: pir))

        // When
        let result = sut.hasFreemiumPIR

        // Then
        XCTAssertTrue(result)
    }
}
