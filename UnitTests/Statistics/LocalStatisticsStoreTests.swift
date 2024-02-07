//
//  LocalStatisticsStoreTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

class LocalStatisticsStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaultsWrapper<Any>.clearAll()
    }

    override func tearDown() {
        super.tearDown()
        UserDefaultsWrapper<Any>.clearAll()
    }

    func testWhenCallingHasInstallStatistics_AndATBExists_ThenItReturnsTrue() {
        let pixelStore = PixelStoreMock()
        let store = LocalStatisticsStore(pixelDataStore: pixelStore)
        store.atb = "atb"

        XCTAssertTrue(store.hasInstallStatistics)
        XCTAssertTrue(store.hasCurrentOrDeprecatedInstallStatistics)
    }

    func testWhenCallingHasInstallStatistics_AndLegacyATBExists_ThenItReturnsTrue() {
        let pixelStore = PixelStoreMock()
        let store = LocalStatisticsStore(pixelDataStore: pixelStore)
        pixelStore.set("atb", forKey: "statistics.atb.key")

        XCTAssertFalse(store.hasInstallStatistics)
        XCTAssertTrue(store.hasCurrentOrDeprecatedInstallStatistics)
    }

    func testWaitlistUnlocked() {
        let pixelStore = PixelStoreMock()
        let store = LocalStatisticsStore(pixelDataStore: pixelStore)

        XCTAssertFalse(store.waitlistUnlocked)
        store.waitlistUnlocked = true
        XCTAssertTrue(store.waitlistUnlocked)
        XCTAssertEqual(pixelStore.data.count, 1)

        store.waitlistUnlocked = false
        XCTAssertFalse(store.waitlistUnlocked)
        XCTAssertEqual(pixelStore.data.count, 0)
    }

    // Legacy Statistics:

    func testWhenInitializingTheLocalStatisticsStore_ThenLegacyStatisticsAreCleared() {
        let legacyStore = LocalStatisticsStore.LegacyStatisticsStore()
        legacyStore.atb = "atb"

        XCTAssertNotNil(legacyStore.atb)
        XCTAssertFalse(legacyStore.legacyStatisticsStoreDataCleared)

        let pixelStore = PixelStoreMock()
        _ = LocalStatisticsStore(pixelDataStore: pixelStore)

        XCTAssertNil(legacyStore.atb)
        XCTAssertTrue(legacyStore.legacyStatisticsStoreDataCleared)
    }

    func testWhenClearingATBData_AndATBDataExists_ThenLegacyStatisticsStoreDataClearedIsTrue() {
        var legacyStore = LocalStatisticsStore.LegacyStatisticsStore()
        legacyStore.atb = "atb"
        legacyStore.clear()

        XCTAssertTrue(legacyStore.legacyStatisticsStoreDataCleared)
    }

    func testWhenClearingATBData_AndATBDataDoesNotExist_ThenLegacyStatisticsStoreDataClearedIsFalse() {
        var legacyStore = LocalStatisticsStore.LegacyStatisticsStore()
        legacyStore.clear()

        XCTAssertFalse(legacyStore.legacyStatisticsStoreDataCleared)
    }

    func testWhenClearingATBData_AndATBDataExists_AndClearIsCalledMultipleTimes_ThenLegacyStatisticsStoreDataClearedIsTrue() {
        var legacyStore = LocalStatisticsStore.LegacyStatisticsStore()
        legacyStore.installDate = Date()
        legacyStore.clear()
        legacyStore.clear()
        legacyStore.clear()

        XCTAssertTrue(legacyStore.legacyStatisticsStoreDataCleared)
    }

}
