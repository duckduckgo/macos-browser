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
        static let didPostFirstProfileSavedNotification = "macos.browser.freemium.pir.did.post.first.profile.saved.notification"
        static let didPostResultsNotification = "macos.browser.freemium.pir.did.post.results.notification"
        static let didDismissHomePagePromotion = "macos.browser.freemium.pir.did.post.dismiss.home.page.promotion"
        static let firstProfileSavedTimestamp = "macos.browser.freemium.pir.first.profile.saved.timestamp"
        static let firstScanResults = "macos.browser.freemium.pir.first.scan.results"
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

    func testSetsDidPostFirstProfileSavedNotification() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(testUserDefaults.bool(forKey: Keys.didPostFirstProfileSavedNotification))

        // When
        sut.didPostFirstProfileSavedNotification = true

        // Then
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didPostFirstProfileSavedNotification))
    }

    func testGetsDidPostFirstProfileSavedNotification() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(sut.didPostFirstProfileSavedNotification)
        testUserDefaults.setValue(true, forKey: Keys.didPostFirstProfileSavedNotification)
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didPostFirstProfileSavedNotification))

        // When
        let result = sut.didPostFirstProfileSavedNotification

        // Then
        XCTAssertTrue(result)
    }

    func testSetsDidPostResultsNotification() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(testUserDefaults.bool(forKey: Keys.didPostResultsNotification))

        // When
        sut.didPostResultsNotification = true

        // Then
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didPostResultsNotification))
    }

    func testGetsDidPostResultsNotification() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(sut.didPostResultsNotification)
        testUserDefaults.setValue(true, forKey: Keys.didPostResultsNotification)
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didPostResultsNotification))

        // When
        let result = sut.didPostResultsNotification

        // Then
        XCTAssertTrue(result)
    }

    func testSetsDidDismissHomePagePromotion() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(testUserDefaults.bool(forKey: Keys.didDismissHomePagePromotion))

        // When
        sut.didDismissHomePagePromotion = true

        // Then
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didDismissHomePagePromotion))
    }

    func testGetsDidDismissHomePagePromotion() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertFalse(sut.didDismissHomePagePromotion)
        testUserDefaults.setValue(true, forKey: Keys.didDismissHomePagePromotion)
        XCTAssertTrue(testUserDefaults.bool(forKey: Keys.didDismissHomePagePromotion))

        // When
        let result = sut.didDismissHomePagePromotion

        // Then
        XCTAssertTrue(result)
    }

    func testSetsFirstScanResults() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertNil(testUserDefaults.data(forKey: Keys.firstScanResults))

        // When
        let scanResults = FreemiumDBPMatchResults(matchesCount: 3, brokerCount: 2)
        sut.firstScanResults = scanResults

        // Then
        let storedData = testUserDefaults.data(forKey: Keys.firstScanResults)
        XCTAssertNotNil(storedData)

        // Decode and verify the result
        let decodedResults = try? JSONDecoder().decode(FreemiumDBPMatchResults.self, from: storedData!)
        XCTAssertEqual(decodedResults?.matchesCount, scanResults.matchesCount)
        XCTAssertEqual(decodedResults?.brokerCount, scanResults.brokerCount)
    }

    func testGetsFirstScanResults() throws {
        // Given
        let sut = DefaultFreemiumPIRUserStateManager(userDefaults: testUserDefaults)
        XCTAssertNil(sut.firstScanResults)

        // When
        let scanResults = FreemiumDBPMatchResults(matchesCount: 3, brokerCount: 2)
        let encodedResults = try JSONEncoder().encode(scanResults)
        testUserDefaults.set(encodedResults, forKey: Keys.firstScanResults)

        // Then
        let result = sut.firstScanResults
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchesCount, scanResults.matchesCount)
        XCTAssertEqual(result?.brokerCount, scanResults.brokerCount)
    }
}
