//
//  SyncPromoManagerTests.swift
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
@testable import BrowserServicesKit
@testable import DDGSync
@testable import DuckDuckGo_Privacy_Browser

final class SyncPromoManagerTests: XCTestCase {

    var syncService: MockDDGSyncing!
    let privacyConfigurationManager = MockPrivacyConfigurationManager()
    let config = MockPrivacyConfiguration()

    override func setUpWithError() throws {
        try super.setUpWithError()

        UserDefaultsWrapper<Any>.clearAll()

        privacyConfigurationManager.privacyConfig = config
        syncService = MockDDGSyncing(authState: .inactive, scheduler: CapturingScheduler(), isSyncInProgress: false)
    }

    override func tearDownWithError() throws {
        UserDefaultsWrapper<Any>.clearAll()
        syncService = nil

        super.tearDown()
    }

    func testWhenAllConditionsMetThenShouldPresentPromoForBookmarks() {
        config.isSubfeatureKeyEnabled = { _, _ in
            return true
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertTrue(syncPromoManager.shouldPresentPromoFor(.bookmarks))
    }

    func testWhenSyncPromotionBookmarksFeatureFlagDisabledThenShouldNotPresentPromoForBookmarks() {
        config.isSubfeatureKeyEnabled = { subfeature, _ in
            if subfeature.rawValue == SyncSubfeature.level0ShowSync.rawValue {
                return true
            }
            return false
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.bookmarks))
    }

    func testWhenSyncFeatureFlagDisabledThenShouldNotPresentPromoForBookmarks() {
        config.isSubfeatureKeyEnabled = { subfeature, _ in
            if subfeature.rawValue == SyncPromotionSubfeature.bookmarks.rawValue {
                return true
            }
            return false
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.bookmarks))
    }

    func testWhenSyncServiceAuthStateActiveThenShouldNotPresentPromoForBookmarks() {
        config.isSubfeatureKeyEnabled = { _, _ in
            return true
        }
        syncService.authState = .active

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.bookmarks))
    }

    func testWhenSyncPromoBookmarksDismissedThenShouldNotPresentPromoForBookmarks() {
        config.isSubfeatureKeyEnabled = { _, _ in
            return true
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()
        syncPromoManager.dismissPromoFor(.bookmarks)

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.bookmarks))
    }

    func testWhenAllConditionsMetThenShouldPresentPromoForPasswords() {
        config.isSubfeatureKeyEnabled = { _, _ in
            return true
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertTrue(syncPromoManager.shouldPresentPromoFor(.passwords))
    }

    func testWhenSyncPromotionPasswordsFeatureFlagDisabledThenShouldNotPresentPromoForPasswords() {
        config.isSubfeatureKeyEnabled = { subfeature, _ in
            if subfeature.rawValue == SyncPromotionSubfeature.passwords.rawValue {
                return false
            }
            return true
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.passwords))
    }

    func testWhenSyncFeatureFlagDisabledThenShouldNotPresentPromoForPasswords() {
        config.isSubfeatureKeyEnabled = { subfeature, _ in
            if subfeature.rawValue == SyncSubfeature.level0ShowSync.rawValue {
                return false
            }
            return true
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.passwords))
    }

    func testWhenSyncServiceAuthStateActiveThenShouldNotPresentPromoForPasswords() {
        config.isSubfeatureKeyEnabled = { _, _ in
            return true
        }
        syncService.authState = .active

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.passwords))
    }

    func testWhenSyncPromoPasswordsDismissedThenShouldNotPresentPromoForPasswords() {
        config.isSubfeatureKeyEnabled = { _, _ in
            return true
        }
        syncService.authState = .inactive

        let syncPromoManager = SyncPromoManager(syncService: syncService, privacyConfigurationManager: privacyConfigurationManager)
        syncPromoManager.resetPromos()
        syncPromoManager.dismissPromoFor(.passwords)

        XCTAssertFalse(syncPromoManager.shouldPresentPromoFor(.passwords))
    }
}
