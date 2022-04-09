//
//  MacWaitlistStoreTests.swift
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

class MacWaitlistStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaultsWrapper<Any>.clearAll()
    }

    override func tearDown() {
        super.tearDown()
        UserDefaultsWrapper<Any>.clearAll()
    }

    func testWhenStoreDoesNotHaveInstallMetadata_ThenIsUnlockedReturnsFalse() {
        let mockStatisticsStore = mockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)

        XCTAssertFalse(store.isUnlocked())
    }

    func testWhenStoreHasInstallMetadata_ThenIsUnlockedReturnsTrue() {
        let mockStatisticsStore = mockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)

        store.unlock()

        XCTAssertTrue(store.isUnlocked())
    }

    func testWhenStoreUnlocks_ThenMetadataIsStoredToDisk() {
        let mockStatisticsStore = mockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)

        XCTAssertFalse(mockStatisticsStore.waitlistUnlocked)
        store.unlock()
        XCTAssertTrue(mockStatisticsStore.waitlistUnlocked)
    }

    func testWhenStoreDeletesMetadata_ThenMetadataIsRemoved() {
        let mockStatisticsStore = mockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)

        store.unlock()
        XCTAssertTrue(mockStatisticsStore.waitlistUnlocked)

        store.deleteExistingMetadata()
        XCTAssertFalse(mockStatisticsStore.waitlistUnlocked)
    }

    private func mockStatisticsStore() -> StatisticsStore {
        let pixelStore = PixelStoreMock()
        return LocalStatisticsStore(pixelDataStore: pixelStore)
    }

}
