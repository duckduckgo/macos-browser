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
    
    func testWhenNoInstallStatisticsAreFound_ThenTheAppIsNotAnExistingInstall() {
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = nil

        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        XCTAssertFalse(store.isExistingInstall())
    }
    
    func testWhenInstallStatisticsAreFound_ThenTheAppIsAnExistingInstall() {
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = "2021-1-1"

        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        XCTAssertTrue(store.isExistingInstall())
    }
    
    func testWhenStoreDoesNotHaveInstallMetadata_ThenIsUnlockedReturnsFalse() {
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        XCTAssertFalse(store.isUnlocked())
    }
    
    func testWhenStoreHasInstallMetadata_ThenIsUnlockedReturnsTrue() {
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        store.unlock()

        XCTAssertTrue(store.isUnlocked())
    }

    func testWhenStoreUnlocks_ThenMetadataIsStoredToDisk() {
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        XCTAssertFalse(mockStatisticsStore.waitlistUpgradeCheckComplete)
        XCTAssertFalse(mockStatisticsStore.waitlistUnlocked)
        store.unlock()
        XCTAssertTrue(mockStatisticsStore.waitlistUpgradeCheckComplete)
        XCTAssertTrue(mockStatisticsStore.waitlistUnlocked)
    }
    
    func testWhenStoreDeletesMetadata_ThenMetadataIsRemoved() {
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        store.unlock()
        XCTAssertTrue(mockStatisticsStore.waitlistUpgradeCheckComplete)
        XCTAssertTrue(mockStatisticsStore.waitlistUnlocked)
        
        store.deleteExistingMetadata()
        XCTAssertFalse(mockStatisticsStore.waitlistUpgradeCheckComplete)
        XCTAssertFalse(mockStatisticsStore.waitlistUnlocked)
    }
    
    func testWhenUnlockingExistingInstall_And_ATBIsSet_ThenInstallIsUnlocked() {
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = "atb"

        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        store.unlockExistingInstallIfNecessary()
        
        XCTAssertTrue(store.isUnlocked())
    }
    
    func testWhenUnlockingExistingInstall_And_ATBIsNotSet_ThenInstallRemainsLocked() {
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = nil

        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        
        store.unlockExistingInstallIfNecessary()
        
        XCTAssertFalse(store.isUnlocked())
    }
    
    func testWhenUnlockingExistingInstall_AndATBIsNotSet_AndATBIsLaterSet_ThenInstallRemainsLocked() {
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = nil

        let store = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore)
        store.unlockExistingInstallIfNecessary()
        XCTAssertFalse(store.isUnlocked())
        
        // Verify that the store remembers that ATB was not initially set and can't be tricked into unlocking by setting
        // it and trying again.
        mockStatisticsStore.atb = "atb"
        store.unlockExistingInstallIfNecessary()
        XCTAssertFalse(store.isUnlocked())
        
        // When receiving a legitimate unlock attempt at this point, it should unlock.
        store.unlock()
        XCTAssertTrue(store.isUnlocked())
    }
    
}
