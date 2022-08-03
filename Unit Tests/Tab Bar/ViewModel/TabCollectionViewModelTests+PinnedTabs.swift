//
//  TabCollectionViewModelTests+PinnedTabs.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

// MARK: - Tests for TabCollectionViewModel with pinned tabs

extension TabCollectionViewModelTests {

    // MARK: - Select

    func test_WithPinnedTabs_WhenTabCollectionViewModelIsInitializedThenSelectedTabViewModelIsFirst() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithPinnedTabs_WhenSelectionIndexIsOutOfBoundsThenSelectedTabViewModelIsNil() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        tabCollectionViewModel.select(at: .unpinned(1))
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)

        tabCollectionViewModel.select(at: .pinned(1))
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)
    }

    func test_WithPinnedTabs_WhenSelectionIndexPointsToPinnedTabThenSelectedTabViewModelReturnsTheTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        tabCollectionViewModel.select(at: .pinned(0))

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 0))
    }

    func test_WithPinnedTabs_WhenSelectNextIsCalledThenNextPinnedTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()

        tabCollectionViewModel.select(at: .pinned(0))
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 1))
    }

    func test_WithPinnedTabs_WhenLastUnpinnedTabIsSelectedThenSelectNextChangesSelectionToFirstPinnedTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        tabCollectionViewModel.select(at: .last(in: tabCollectionViewModel))
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 0))
    }

    func test_WithPinnedTabs_WhenLastPinnedTabIsSelectedThenSelectNextChangesSelectionToFirstUnpinnedTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        tabCollectionViewModel.select(at: .pinned(0))
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func test_WithPinnedTabs_WhenSelectPreviousIsCalledThenPreviousPinnedTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()

        tabCollectionViewModel.select(at: .pinned(1))
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 0))
    }

    func test_WithPinnedTabs_WhenFirstUnpinnedTabIsSelectedThenSelectPreviousChangesSelectionToLastPinnedTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()

        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 1))
    }

    func test_WithPinnedTabs_WhenFirstPinnedTabIsSelectedThenSelectPreviousChangesSelectionToLastUnpinnedTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        tabCollectionViewModel.select(at: .pinned(0))
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    // MARK: - Insert

    func test_WithPinnedTabs_WhenInsertChildOfPinnedTabAndNoOtherChildTabIsNearParent_ThenTabIsInsertedAsFirstUnpinnedTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        let parentPinnedTab = tabCollectionViewModel.pinnedTabsManager!.tabCollection.tabs[0]

        let tab = Tab(parentTab: parentPinnedTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 2)
        XCTAssertIdentical(tab, tabCollectionViewModel.tabViewModel(at: 0)?.tab)
    }

    func test_WithPinnedTabs_WhenInsertChildOfPinnedTabAndOtherChildTabsAreNearParent_ThenTabIsInsertedAtTheEndOfChildList() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendNewTab()

        let parentPinnedTab = tabCollectionViewModel.pinnedTabsManager!.tabCollection.tabs[0]

        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentPinnedTab), selected: false)
        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentPinnedTab), selected: false)
        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentPinnedTab), selected: false)

        let tab = Tab(parentTab: parentPinnedTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: true)

        XCTAssertIdentical(tab, tabCollectionViewModel.tabViewModel(at: 3)?.tab)
    }

    // MARK: - Remove

    func test_WithPinnedTabs_WhenRemoveIsCalledWithIndexOutOfBoundsThenNoTabIsRemoved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        tabCollectionViewModel.remove(at: .pinned(1))

        XCTAssertEqual(tabCollectionViewModel.pinnedTabsCollection?.tabs.count, 1)
    }

    func test_WithPinnedTabs_WhenPinnedTabIsRemovedAndSelectedPinnedTabHasHigherIndexThenSelectionIsPreserved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()
        tabCollectionViewModel.appendPinnedTab()

        tabCollectionViewModel.select(at: .pinned(2))
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.remove(at: .pinned(1))

        XCTAssertIdentical(selectedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
        XCTAssertEqual(tabCollectionViewModel.selectionIndex, .pinned(1))
    }

    func test_WithPinnedTabs_WhenSelectedPinnedTabIsRemovedThenNextPinnedTabWithHigherIndexIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()
        tabCollectionViewModel.appendPinnedTab()
        let lastPinnedTab = tabCollectionViewModel.pinnedTabsCollection?.tabs[2]

        tabCollectionViewModel.select(at: .pinned(1))
        tabCollectionViewModel.remove(at: .pinned(1))

        XCTAssertIdentical(lastPinnedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
        XCTAssertEqual(tabCollectionViewModel.selectionIndex, .pinned(1))
    }

    func test_WithPinnedTabs_WhenSelectedLastPinnedTabIsRemovedThenFirstUnpinnedTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()
        let firstUnpinnedTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.select(at: .pinned(1))
        tabCollectionViewModel.remove(at: .pinned(1))

        XCTAssertIdentical(firstUnpinnedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
        XCTAssertEqual(tabCollectionViewModel.selectionIndex, .unpinned(0))
    }

    func test_WithPinnedTabs_WhenLastTabIsRemoved_ThenLastPinnedTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()
        let lastPinnedTab = tabCollectionViewModel.pinnedTabsCollection?.tabs[1]

        tabCollectionViewModel.remove(at: .unpinned(0))

        XCTAssertIdentical(lastPinnedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
        XCTAssertEqual(tabCollectionViewModel.selectionIndex, .pinned(1))
    }

    func test_WithPinnedTabs_WhenNoTabIsSelectedAndTabIsRemoved_ThenSelectionStaysEmpty() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()
        tabCollectionViewModel.appendNewTab()

        // Clear selection
        tabCollectionViewModel.select(at: .pinned(-1))

        tabCollectionViewModel.remove(at: .unpinned(1))

        XCTAssertNil(tabCollectionViewModel.selectionIndex)
    }

    func test_WithPinnedTabs_WhenChildTabIsInsertedAndRemoved_ThenPinnedParentIsSelectedBack() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendPinnedTab()
        let parentTab = tabCollectionViewModel.pinnedTabsCollection!.tabs[0]

        let childTab1 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab1, selected: false)
        let childTab2 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab2, selected: true)

        tabCollectionViewModel.remove(at: .unpinned(2))

        XCTAssertIdentical(tabCollectionViewModel.selectedTabViewModel?.tab, parentTab)
        XCTAssertEqual(tabCollectionViewModel.selectionIndex, .pinned(0))
    }

    func test_WithPinnedTabs_WhenPinnedOwnerOfWebviewIsRemovedThenAllOtherTabsRemained() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        let pinnedTabViewModel = tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 0)!

        tabCollectionViewModel.remove(ownerOf: pinnedTabViewModel.tab.webView)

        XCTAssertFalse(tabCollectionViewModel.pinnedTabsCollection!.tabs.contains(pinnedTabViewModel.tab))
        XCTAssertTrue(tabCollectionViewModel.pinnedTabsCollection!.tabs.isEmpty)
    }

    func test_WithPinnedTabs_RemoveSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        tabCollectionViewModel.select(at: .pinned(0))
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.removeSelected()

        XCTAssertFalse(tabCollectionViewModel.pinnedTabsCollection!.tabs.contains(selectedTab!))
    }

    // MARK: - Duplicate

    func test_WithPinnedTabs_WhenPinnedTabIsDuplicatedThenItsCopyHasHigherIndexByOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModelWithPinnedTab()
        let firstTabViewModel = tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 0)

        tabCollectionViewModel.duplicateTab(at: .pinned(0))

        XCTAssertIdentical(firstTabViewModel, tabCollectionViewModel.pinnedTabsManager!.tabViewModel(at: 0))
    }
}

fileprivate extension TabCollectionViewModel {

    static func aTabCollectionViewModelWithPinnedTab() -> TabCollectionViewModel {
        let tabCollection = TabCollection()
        let pinnedTabsManager = PinnedTabsManager()
        let vm = TabCollectionViewModel(tabCollection: tabCollection, pinnedTabsManager: pinnedTabsManager)
        vm.appendPinnedTab()
        return vm
    }

    func appendPinnedTab() {
        pinnedTabsManager?.tabCollection.append(tab: .init(content: .url("https://duck.com".url!)))
    }
}
