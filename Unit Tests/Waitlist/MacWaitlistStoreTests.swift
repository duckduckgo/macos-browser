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
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = nil

        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        XCTAssertFalse(store.isExistingInstall())
    }
    
    func testWhenInstallStatisticsAreFound_ThenTheAppIsAnExistingInstall() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = "2021-1-1"

        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        XCTAssertTrue(store.isExistingInstall())
    }
    
    func testWhenStoreDoesNotHaveInstallMetadata_ThenIsUnlockedReturnsFalse() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        XCTAssertFalse(store.isUnlocked())
    }
    
    func testWhenStoreHasInstallMetadata_ThenIsUnlockedReturnsTrue() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        store.unlock()

        XCTAssertTrue(store.isUnlocked())
    }

    func testWhenStoreUnlocks_ThenMetadataIsStoredToDisk() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        XCTAssertTrue(mockFileStore.storage.isEmpty)
        store.unlock()
        XCTAssertFalse(mockFileStore.storage.isEmpty)
    }
    
    func testWhenStoreDeletesMetadata_ThenMetadataIsRemoved() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        store.unlock()
        XCTAssertFalse(mockFileStore.storage.isEmpty)
        
        store.deleteExistingMetadata()
        XCTAssertTrue(mockFileStore.storage.isEmpty)
    }
    
    func testWhenUnlockingExistingInstall_And_ATBIsSet_ThenInstallIsUnlocked() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = "atb"

        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        store.unlockExistingInstallIfNecessary()
        
        XCTAssertTrue(store.isUnlocked())
    }
    
    func testWhenUnlockingExistingInstall_And_ATBIsNotSet_ThenInstallRemainsLocked() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = nil

        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
        
        store.unlockExistingInstallIfNecessary()
        
        XCTAssertFalse(store.isUnlocked())
    }
    
    func testWhenUnlockingExistingInstall_AndATBIsNotSet_AndATBIsLaterSet_ThenInstallRemainsLocked() {
        let mockFileStore = FileStoreMock()
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = nil

        let store = MacWaitlistEncryptedFileStorage(fileStore: mockFileStore, statisticsStore: mockStatisticsStore)
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
