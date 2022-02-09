//
//  TabCollectionViewModelTests.swift
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

final class TabCollectionViewModelTests: XCTestCase {

    // MARK: - TabViewModel

    func testWhenTabViewModelIsCalledWithIndexOutOfBoundsThenNilIsReturned() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssertNil(tabCollectionViewModel.tabViewModel(at: 1))
    }

    func testWhenTabViewModelIsCalledThenAppropriateTabViewModelIsReturned() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssertEqual(tabCollectionViewModel.tabViewModel(at: 0)?.tab,
                       tabCollectionViewModel.tabCollection.tabs[0])
    }

    func testWhenTabViewModelIsCalledWithSameIndexThenTheResultHasSameIdentity() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssert(tabCollectionViewModel.tabViewModel(at: 0) === tabCollectionViewModel.tabViewModel(at: 0))
    }

    // MARK: - Select

    func testWhenTabCollectionViewModelIsInitializedThenSelectedTabViewModelIsFirst() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }
    
    func testWhenSelectionIndexIsOutOfBoundsThenSelectedTabViewModelIsNil() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        
        tabCollectionViewModel.select(at: 1)
        
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)
    }
    
    func testWhenSelectionIndexPointsToTabThenSelectedTabViewModelReturnsTheTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: 0)
        
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func testWhenSelectNextIsCalledThenNextTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: 0)
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    func testWhenLastTabIsSelectedThenSelectNextChangesSelectionToFirstOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func testWhenSelectPreviousIsCalledThenPreviousTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func testWhenFirstTabIsSelectedThenSelectPreviousChangesSelectionToLastOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: 0)
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    // MARK: - Append

    func testWhenAppendNewTabIsCalledThenNewTabIsAlsoSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let index = tabCollectionViewModel.tabCollection.tabs.count
        tabCollectionViewModel.appendNewTab()
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: index))
    }

    func testWhenTabIsAppendedWithSelectedAsFalseThenSelectionIsPreserved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel

        tabCollectionViewModel.append(tab: Tab(), selected: false)

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === selectedTabViewModel)
    }

    func testWhenTabIsAppendedWithSelectedAsTrueThenNewTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.append(tab: Tab(), selected: true)
        let lastTabViewModel = tabCollectionViewModel.tabViewModel(at: tabCollectionViewModel.tabCollection.tabs.count - 1)

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === lastTabViewModel)
    }

    func testWhenMultipleTabsAreAppendedThenTheLastOneIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let lastTab = Tab()
        tabCollectionViewModel.append(tabs: [Tab(), lastTab])

        XCTAssert(tabCollectionViewModel.selectedTabViewModel?.tab === lastTab)
    }

    // MARK: - Insert

    func testWhenInsertChildAndParentIsNil_ThenNoChildIsInserted() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let tab = Tab()
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab !== tabCollectionViewModel.tabViewModel(at: 0)?.tab)
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.count == 1)
    }

    func testWhenInsertChildAndParentIsntPartOfTheTabCollection_ThenNoChildIsInserted() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let parentTab = Tab()
        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab !== tabCollectionViewModel.tabViewModel(at: 0)?.tab)
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.count == 1)
    }

    func testWhenInsertChildAndNoOtherChildTabIsNearParent_ThenTabIsInsertedRightNextToParent() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let parentTab = Tab()
        tabCollectionViewModel.append(tab: parentTab)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 2)?.tab)
    }

    func testWhenInsertChildAndOtherChildTabsAreNearParent_ThenTabIsInsertedAtTheEndOfChildList() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()

        let parentTab = Tab()
        tabCollectionViewModel.insert(tab: parentTab, at: 1, selected: true)

        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentTab), selected: false)
        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentTab), selected: false)
        tabCollectionViewModel.insertChild(tab: Tab(parentTab: parentTab), selected: false)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: true)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 5)?.tab)
    }

    func testWhenInsertChildAndParentIsLast_ThenTabIsAppendedAtTheEnd() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()

        let parentTab = Tab()
        tabCollectionViewModel.insert(tab: parentTab, at: 1, selected: true)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insertChild(tab: tab, selected: false)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 2)?.tab)
    }

    // MARK: - Remove

    func testWhenRemoveIsCalledWithIndexOutOfBoundsThenNoTabIsRemoved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.remove(at: 1)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
    }

    func testWhenTabIsRemovedAndSelectedTabHasHigherIndexThenSelectionIsPreserved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.remove(at: 0)

        XCTAssertEqual(selectedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func testWhenSelectedTabIsRemovedThenNextItemWithLowerIndexIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.remove(at: 1)

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func testWhenAllOtherTabsAreRemovedThenRemainedIsAlsoSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        tabCollectionViewModel.removeAllTabs(except: 0)

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func testWhenLastTabIsRemoved_ThenSelectionIsNil() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.remove(at: 0)

        XCTAssertNil(tabCollectionViewModel.selectionIndex)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 0)
    }

    func testWhenNoTabIsSelectedAndTabIsRemoved_ThenSelectionStaysEmpty() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        // Clear selection
        tabCollectionViewModel.select(at: -1)

        tabCollectionViewModel.remove(at: 1)

        XCTAssertNil(tabCollectionViewModel.selectionIndex)
    }

    func testWhenChildTabIsInsertedAndRemoved_ThenParentIsSelectedBack() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let parentTab = tabCollectionViewModel.tabCollection.tabs[0]
        let childTab1 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab1, selected: false)
        let childTab2 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab2, selected: true)

        tabCollectionViewModel.remove(at: 2)

        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab, parentTab)
    }

    func testWhenChildTabOnLeftHasTheSameParentAndTabOnRightDont_ThenTabOnLeftIsSelectedAfterRemoval() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let parentTab = tabCollectionViewModel.tabCollection.tabs[0]
        let childTab1 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab1, selected: false)
        let childTab2 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab2, selected: true)
        tabCollectionViewModel.appendNewTab()

        // Select and remove childTab2
        tabCollectionViewModel.selectPrevious()
        tabCollectionViewModel.removeSelected()

        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab, childTab1)
    }

    func testWhenOwnerOfWebviewIsRemovedThenAllOtherTabsRemained() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        let lastTabViewModel = tabCollectionViewModel.tabViewModel(at: tabCollectionViewModel.tabCollection.tabs.count - 1)!

        tabCollectionViewModel.remove(ownerOf: lastTabViewModel.tab.webView)

        XCTAssertFalse(tabCollectionViewModel.tabCollection.tabs.contains(lastTabViewModel.tab))
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.count == 2)
    }

    func testWhenOwnerOfWebviewIsNotInTabCollectionThenNoTabIsRemoved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let originalCount = tabCollectionViewModel.tabCollection.tabs.count
        let tab = Tab()

        tabCollectionViewModel.remove(ownerOf: tab.webView)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, originalCount)
    }

    func testRemoveSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.removeSelected()

        XCTAssertFalse(tabCollectionViewModel.tabCollection.tabs.contains(selectedTab!))
    }

    // MARK: - Duplicate

    func testWhenTabIsDuplicatedThenItsCopyHasHigherIndexByOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)

        tabCollectionViewModel.duplicateTab(at: 0)

        XCTAssert(firstTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func testWhenTabIsDuplicatedThenItsCopyHasTheSameUrl() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)
        firstTabViewModel?.tab.url = URL.duckDuckGo

        tabCollectionViewModel.duplicateTab(at: 0)

        XCTAssertEqual(firstTabViewModel?.tab.url, tabCollectionViewModel.tabViewModel(at: 1)?.tab.url)
    }

}

fileprivate extension TabCollectionViewModel {

    static func aTabCollectionViewModel() -> TabCollectionViewModel {
        let tabCollection = TabCollection()
        return TabCollectionViewModel(tabCollection: tabCollection)
    }

}

extension Tab {
    convenience init(parentTab: Tab) {
        self.init(content: .url(.blankPage), parentTab: parentTab)
    }
}
