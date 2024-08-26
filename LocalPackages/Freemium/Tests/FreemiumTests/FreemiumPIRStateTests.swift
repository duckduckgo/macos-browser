//
//  FreemiumPIRStateTests.swift
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
import Subscription

final class FreemiumPIRStateTests: XCTestCase {

    private static let testSuiteName = "test.defaults.freemium.state.tests"
    private let pir = "macos.browser.freemium.pir"
    private let testUserDefaults = UserDefaults(suiteName: FreemiumPIRStateTests.testSuiteName)!
    private var mockAccountManager: MockAccountManager!

    override func setUpWithError() throws {
        mockAccountManager = MockAccountManager()
        testUserDefaults.removePersistentDomain(forName: FreemiumPIRStateTests.testSuiteName)
    }

    func testSetsHasFreemiumPIR() throws {
        // Given
        let sut = DefaultFreemiumPIRState(userDefaults: testUserDefaults, accountManager: mockAccountManager)
        XCTAssertFalse(testUserDefaults.bool(forKey: pir))

        // When
        sut.didOnboard = true

        // Then
        XCTAssertTrue(testUserDefaults.bool(forKey: pir))
    }

    func testGetsHasFreemiumPIR() throws {
        // Given
        let sut = DefaultFreemiumPIRState(userDefaults: testUserDefaults, accountManager: mockAccountManager)
        XCTAssertFalse(sut.didOnboard)
        testUserDefaults.setValue(true, forKey: pir)
        XCTAssertTrue(testUserDefaults.bool(forKey: pir))

        // When
        let result = sut.didOnboard

        // Then
        XCTAssertTrue(result)
    }

    func testIsCurrentFreemiumPIRUser_WhenDidOnboardIsTrueAndUserIsNotAuthenticated_ShouldReturnTrue() {
        // Given
        let sut = DefaultFreemiumPIRState(userDefaults: testUserDefaults, accountManager: mockAccountManager)
        XCTAssertFalse(sut.didOnboard)
        testUserDefaults.setValue(true, forKey: pir)
        mockAccountManager.accessToken = nil
        XCTAssertTrue(testUserDefaults.bool(forKey: pir))

        // When
        let result = sut.isCurrentUser

        // Then
        XCTAssertTrue(result)
    }

    func testIsCurrentFreemiumPIRUser_WhenDidOnboardIsTrueAndUserIsAuthenticated_ShouldReturnFalse() {
        // Given
        let sut = DefaultFreemiumPIRState(userDefaults: testUserDefaults, accountManager: mockAccountManager)
        XCTAssertFalse(sut.didOnboard)
        testUserDefaults.setValue(true, forKey: pir)
        mockAccountManager.accessToken = "some_token"
        XCTAssertTrue(testUserDefaults.bool(forKey: pir))

        // When
        let result = sut.isCurrentUser

        // Then
        XCTAssertFalse(result)
    }

    func testIsCurrentFreemiumPIRUser_WhenDidOnboardIsFalse_ShouldReturnFalse() {
        // Given
        let sut = DefaultFreemiumPIRState(userDefaults: testUserDefaults, accountManager: mockAccountManager)
        XCTAssertFalse(sut.didOnboard)
        testUserDefaults.setValue(false, forKey: pir)
        mockAccountManager.accessToken = "some_token"
        XCTAssertFalse(testUserDefaults.bool(forKey: pir))

        // When
        let result = sut.isCurrentUser

        // Then
        XCTAssertFalse(result)
    }
}
