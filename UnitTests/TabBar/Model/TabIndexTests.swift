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
        XCTAssertLessThan(TabIndex.pinned(0), TabIndex.unpinned(0))
        XCTAssertLessThan(TabIndex.pinned(0), TabIndex.pinned(1))
        XCTAssertLessThan(TabIndex.pinned(100), TabIndex.unpinned(0))
        XCTAssertLessThan(TabIndex.pinned(100), TabIndex.unpinned(200))
        XCTAssertLessThan(TabIndex.unpinned(100), TabIndex.unpinned(200))
    }

    func testIndex() {
        XCTAssertEqual(TabIndex.pinned(4).item, 4)
        XCTAssertEqual(TabIndex.unpinned(2).item, 2)
    }

    func testIsPinned() {
        XCTAssertTrue(TabIndex.pinned(5).isPinnedTab)
        XCTAssertFalse(TabIndex.unpinned(5).isPinnedTab)
    }

    func testIsUnpinned() {
        XCTAssertTrue(TabIndex.unpinned(5).isUnpinnedTab)
        XCTAssertFalse(TabIndex.pinned(5).isUnpinnedTab)
    }

    func testMakeNext() {
        XCTAssertEqual(TabIndex.unpinned(0).makeNext(), TabIndex.unpinned(1))
        XCTAssertEqual(TabIndex.unpinned(41).makeNext(), TabIndex.unpinned(42))
        XCTAssertEqual(TabIndex.pinned(16).makeNext(), TabIndex.pinned(17))
    }

    func testMakeNextUnpinned() {
        XCTAssertEqual(TabIndex.unpinned(0).makeNextUnpinned(), TabIndex.unpinned(1))
        XCTAssertEqual(TabIndex.unpinned(41).makeNextUnpinned(), TabIndex.unpinned(42))
        XCTAssertEqual(TabIndex.pinned(0).makeNextUnpinned(), TabIndex.unpinned(0))
        XCTAssertEqual(TabIndex.pinned(2).makeNextUnpinned(), TabIndex.unpinned(0))
    }

    @MainActor
    func testWhenViewModelHasNoPinnedTabsThenFirstTabIsUnpinned() {
        let tabCollectionViewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 1),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.first(in: tabCollectionViewModel), .unpinned(0))
    }

    @MainActor
    func testWhenViewModelHasPinnedTabsThenFirstTabIsPinned() {
        let tabCollectionViewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 1),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 1)
        )

        XCTAssertEqual(TabIndex.first(in: tabCollectionViewModel), .pinned(0))
    }

    @MainActor
    func testLastTab() {
        let tabCollectionViewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 10),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.last(in: tabCollectionViewModel), .unpinned(9))
    }

    @MainActor
    func testThatNextInViewModelCyclesThroughPinnedAndUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 2),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 3)
        )

        XCTAssertEqual(TabIndex.pinned(0).next(in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.pinned(1).next(in: viewModel), .pinned(2))
        XCTAssertEqual(TabIndex.pinned(2).next(in: viewModel), .unpinned(0))
        XCTAssertEqual(TabIndex.unpinned(0).next(in: viewModel), .unpinned(1))
        XCTAssertEqual(TabIndex.unpinned(1).next(in: viewModel), .pinned(0))
    }

    @MainActor
    func testWhenViewModelHasNoPinnedTabsThenNextInViewModelCyclesThroughUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 2),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.unpinned(0).next(in: viewModel), .unpinned(1))
        XCTAssertEqual(TabIndex.unpinned(1).next(in: viewModel), .unpinned(0))
    }

    @MainActor
    func testWhenViewModelHasNoUnpinnedTabsThenNextInViewModelCyclesThroughPinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 0),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 3)
        )
        viewModel.remove(at: .unpinned(0))

        XCTAssertEqual(TabIndex.pinned(0).next(in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.pinned(1).next(in: viewModel), .pinned(2))
        XCTAssertEqual(TabIndex.pinned(2).next(in: viewModel), .pinned(0))
    }

    @MainActor
    func testThatPreviousInViewModelCyclesThroughPinnedAndUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 2),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 3)
        )

        XCTAssertEqual(TabIndex.unpinned(1).previous(in: viewModel), .unpinned(0))
        XCTAssertEqual(TabIndex.unpinned(0).previous(in: viewModel), .pinned(2))
        XCTAssertEqual(TabIndex.pinned(2).previous(in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.pinned(1).previous(in: viewModel), .pinned(0))
        XCTAssertEqual(TabIndex.pinned(0).previous(in: viewModel), .unpinned(1))
    }

    @MainActor
    func testWhenViewModelHasNoPinnedTabsThenPreviousInViewModelCyclesThroughUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 3),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.unpinned(2).previous(in: viewModel), .unpinned(1))
        XCTAssertEqual(TabIndex.unpinned(1).previous(in: viewModel), .unpinned(0))
        XCTAssertEqual(TabIndex.unpinned(0).previous(in: viewModel), .unpinned(2))
    }

    @MainActor
    func testWhenViewModelHasNoUnpinnedTabsThenPreviousInViewModelCyclesThroughPinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 0),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 3)
        )
        viewModel.remove(at: .unpinned(0))

        XCTAssertEqual(TabIndex.pinned(2).previous(in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.pinned(1).previous(in: viewModel), .pinned(0))
        XCTAssertEqual(TabIndex.pinned(0).previous(in: viewModel), .pinned(2))
    }

    @MainActor
    func testThatSanitizedInViewModelReturnsIndexRepresentingExistingTab() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 10),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 5)
        )

        XCTAssertEqual(TabIndex.unpinned(7).sanitized(for: viewModel), .unpinned(7))
        XCTAssertEqual(TabIndex.unpinned(-1).sanitized(for: viewModel), .unpinned(0))
        XCTAssertEqual(TabIndex.unpinned(400).sanitized(for: viewModel), .unpinned(9))
        XCTAssertEqual(TabIndex.pinned(3).sanitized(for: viewModel), .pinned(3))
        XCTAssertEqual(TabIndex.pinned(-3).sanitized(for: viewModel), .pinned(0))
        XCTAssertEqual(TabIndex.pinned(8).sanitized(for: viewModel), .unpinned(3))
        XCTAssertEqual(TabIndex.pinned(800).sanitized(for: viewModel), .unpinned(9))
    }

    @MainActor
    func testThatSanitizedInViewModelReturnsLastPinnedTabIndexWhenThereAreNoPinnedTabsRepresentingExistingTab() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 0),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 5)
        )
        viewModel.remove(at: .unpinned(0))

        XCTAssertEqual(TabIndex.unpinned(0).sanitized(for: viewModel), .pinned(4))
        XCTAssertEqual(TabIndex.unpinned(5).sanitized(for: viewModel), .pinned(4))
    }

    @MainActor
    func testThatAtPositionInViewModelReturnsExistingTab() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 2),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 3)
        )

        XCTAssertEqual(TabIndex.at(0, in: viewModel), .pinned(0))
        XCTAssertEqual(TabIndex.at(1, in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.at(2, in: viewModel), .pinned(2))
        XCTAssertEqual(TabIndex.at(3, in: viewModel), .unpinned(0))
        XCTAssertEqual(TabIndex.at(4, in: viewModel), .unpinned(1))
        XCTAssertEqual(TabIndex.at(5, in: viewModel), .unpinned(1))
        XCTAssertEqual(TabIndex.at(42, in: viewModel), .unpinned(1))
        XCTAssertEqual(TabIndex.at(-5, in: viewModel), .pinned(0))
    }

    @MainActor
    func testThatAtPositionInViewModelReturnsExistingTabWhenThereAreNoPinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 4),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 0)
        )

        XCTAssertEqual(TabIndex.at(0, in: viewModel), .unpinned(0))
        XCTAssertEqual(TabIndex.at(1, in: viewModel), .unpinned(1))
        XCTAssertEqual(TabIndex.at(2, in: viewModel), .unpinned(2))
        XCTAssertEqual(TabIndex.at(3, in: viewModel), .unpinned(3))
        XCTAssertEqual(TabIndex.at(5, in: viewModel), .unpinned(3))
        XCTAssertEqual(TabIndex.at(42, in: viewModel), .unpinned(3))
        XCTAssertEqual(TabIndex.at(-5, in: viewModel), .unpinned(0))
    }

    @MainActor
    func testThatAtPositionInViewModelReturnsExistingTabWhenThereAreNoUnpinnedTabs() {
        let viewModel = TabCollectionViewModel(
            tabCollection: tabCollection(tabsCount: 0),
            pinnedTabsManager: pinnedTabsManager(tabsCount: 4)
        )
        viewModel.remove(at: .unpinned(0))

        XCTAssertEqual(TabIndex.at(0, in: viewModel), .pinned(0))
        XCTAssertEqual(TabIndex.at(1, in: viewModel), .pinned(1))
        XCTAssertEqual(TabIndex.at(2, in: viewModel), .pinned(2))
        XCTAssertEqual(TabIndex.at(3, in: viewModel), .pinned(3))
        XCTAssertEqual(TabIndex.at(5, in: viewModel), .pinned(3))
        XCTAssertEqual(TabIndex.at(42, in: viewModel), .pinned(3))
        XCTAssertEqual(TabIndex.at(-5, in: viewModel), .pinned(0))
    }

    // MARK: -

    @MainActor
    private func tabCollection(tabsCount: Int) -> TabCollection {
        let tab = Tab(content: .url("https://duck.com".url!, source: .link))
        return TabCollection(tabs: .init(repeating: tab, count: tabsCount))
    }

    @MainActor
    private func pinnedTabsManager(tabsCount: Int) -> PinnedTabsManager {
        PinnedTabsManager(tabCollection: tabCollection(tabsCount: tabsCount))
    }
}
