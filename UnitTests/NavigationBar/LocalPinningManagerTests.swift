//
//  LocalPinningManagerTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import NetworkProtection

@testable import DuckDuckGo_Privacy_Browser

final class LocalPinningManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaultsWrapper<Any>.clearAll()
    }

    override func tearDown() {
        super.tearDown()
        UserDefaultsWrapper<Any>.clearAll()
    }

    private func createManager() -> LocalPinningManager {
        return LocalPinningManager()
    }

    func testWhenTogglingPinningForAView_AndViewIsNotPinned_ThenViewBecomesPinned() {
        let manager = createManager()

        XCTAssertFalse(manager.isPinned(.autofill))
        XCTAssertFalse(manager.isPinned(.bookmarks))

        manager.togglePinning(for: .autofill)

        XCTAssertTrue(manager.isPinned(.autofill))
        XCTAssertFalse(manager.isPinned(.bookmarks))
    }

    func testWhenTogglingPinningForAView_AndViewIsAlreadyPinned_ThenViewBecomesUnpinned() {
        let manager = createManager()

        XCTAssertFalse(manager.isPinned(.autofill))
        XCTAssertFalse(manager.isPinned(.bookmarks))

        manager.togglePinning(for: .autofill)

        XCTAssertTrue(manager.isPinned(.autofill))
        XCTAssertFalse(manager.isPinned(.bookmarks))

        manager.togglePinning(for: .autofill)

        XCTAssertFalse(manager.isPinned(.autofill))
        XCTAssertFalse(manager.isPinned(.bookmarks))
    }

    func testWhenChangingPinnedViews_ThenNotificationIsPosted() {
        expectation(forNotification: .PinnedViewsChanged, object: nil)

        let manager = createManager()
        manager.togglePinning(for: .autofill)

        waitForExpectations(timeout: 1.0)
    }

}
