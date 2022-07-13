//
//  TabIndexTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class TabIndexTests: XCTestCase {

    func testComparison() {
        XCTAssertLessThan(TabIndex.pinned(0), TabIndex.regular(0))
        XCTAssertLessThan(TabIndex.pinned(0), TabIndex.pinned(1))
        XCTAssertLessThan(TabIndex.pinned(100), TabIndex.regular(0))
        XCTAssertLessThan(TabIndex.pinned(100), TabIndex.regular(200))
        XCTAssertLessThan(TabIndex.regular(100), TabIndex.regular(200))
    }

    func testIndex() {
        XCTAssertEqual(TabIndex.pinned(4).index, 4)
        XCTAssertEqual(TabIndex.regular(2).index, 2)
    }

    func testIsPinned() {
        XCTAssertTrue(TabIndex.pinned(5).isPinnedTab)
        XCTAssertFalse(TabIndex.regular(5).isPinnedTab)
    }

    func testIsUnpinned() {
        XCTAssertTrue(TabIndex.regular(5).isRegularTab)
        XCTAssertFalse(TabIndex.pinned(5).isRegularTab)
    }

    func testMakeNext() {
        XCTAssertEqual(TabIndex.regular(0).makeNext(), TabIndex.regular(1))
        XCTAssertEqual(TabIndex.regular(41).makeNext(), TabIndex.regular(42))
        XCTAssertEqual(TabIndex.pinned(16).makeNext(), TabIndex.pinned(17))
    }

    func testWhenViewModelHasNoPinnedTabsThenFirstTabIsUnpinned() {
        let tabCollectionViewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 1),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.first(in: tabCollectionViewModel), .regular(0))
    }

    func testWhenViewModelHasPinnedTabsThenFirstTabIsPinned() {
        let tabCollectionViewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 1),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 1)
        )

        XCTAssertEqual(TabIndex.first(in: tabCollectionViewModel), .pinned(0))
    }

    func testThatNextInViewModelCyclesThroughPinnedAndUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 2),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 3)
        )

        XCTAssertEqual(TabIndex.pinned(0).next(in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.pinned(1).next(in: viewModel), .pinned(2))
        XCTAssertEqual(TabIndex.pinned(2).next(in: viewModel), .regular(0))
        XCTAssertEqual(TabIndex.regular(0).next(in: viewModel), .regular(1))
        XCTAssertEqual(TabIndex.regular(1).next(in: viewModel), .pinned(0))
    }

    func testWhenViewModelHasNoPinnedTabsThenNextInViewModelCyclesThroughUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 2),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.regular(0).next(in: viewModel), .regular(1))
        XCTAssertEqual(TabIndex.regular(1).next(in: viewModel), .regular(0))
    }

    func testThatPreviousInViewModelCyclesThroughPinnedAndUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 2),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 3)
        )

        XCTAssertEqual(TabIndex.regular(1).previous(in: viewModel), .regular(0))
        XCTAssertEqual(TabIndex.regular(0).previous(in: viewModel), .pinned(2))
        XCTAssertEqual(TabIndex.pinned(2).previous(in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.pinned(1).previous(in: viewModel), .pinned(0))
        XCTAssertEqual(TabIndex.pinned(0).previous(in: viewModel), .regular(1))
    }

    func testWhenViewModelHasNoPinnedTabsThenPreviousInViewModelCyclesThroughUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 3),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.regular(2).previous(in: viewModel), .regular(1))
        XCTAssertEqual(TabIndex.regular(1).previous(in: viewModel), .regular(0))
        XCTAssertEqual(TabIndex.regular(0).previous(in: viewModel), .regular(2))
    }

    func testThatSanitizedInViewModelReturnsIndexRepresentingExistingTab() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 10),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 5)
        )

        XCTAssertEqual(TabIndex.regular(7).sanitized(for: viewModel), .regular(7))
        XCTAssertEqual(TabIndex.regular(-1).sanitized(for: viewModel), .regular(0))
        XCTAssertEqual(TabIndex.regular(400).sanitized(for: viewModel), .regular(9))
        XCTAssertEqual(TabIndex.pinned(3).sanitized(for: viewModel), .pinned(3))
        XCTAssertEqual(TabIndex.pinned(-3).sanitized(for: viewModel), .pinned(0))
        XCTAssertEqual(TabIndex.pinned(8).sanitized(for: viewModel), .regular(3))
        XCTAssertEqual(TabIndex.pinned(800).sanitized(for: viewModel), .regular(9))
    }

    // MARK: -

    private func tabCollection(tabsCount: Int) -> TabCollection {
        let tab = Tab(content: .url("https://duck.com".url!))
        return TabCollection(tabs: .init(repeating: tab, count: tabsCount))
    }

    private func pinnedTabsManager(tabsCount: Int) -> PinnedTabsManager {
        PinnedTabsManager(tabCollection: tabCollection(tabsCount: tabsCount))
    }
}
