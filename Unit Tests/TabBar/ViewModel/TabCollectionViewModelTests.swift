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

class TabCollectionViewModelTests: XCTestCase {

    // MARK: - TabViewModel

    func testWhenTabViewModelIsCalledWithIndexOutOfBoundsThenNilIsReturned() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        XCTAssertNil(tabCollectionViewModel.tabViewModel(at: 1))
    }

    func testWhenTabViewModelIsCalledThenAppropriateTabViewModelIsReturned() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        XCTAssertEqual(tabCollectionViewModel.tabViewModel(at: 0)?.tab, tabCollection.tabs[0])
    }

    func testWhenTabViewModelIsCalledWithSameIndexThenTheResultHasSameIdentity() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        XCTAssert(tabCollectionViewModel.tabViewModel(at: 0) === tabCollectionViewModel.tabViewModel(at: 0))
    }

    // MARK: - Select

    func testWhenTabCollectionViewModelIsInitializedThenSelectedTabViewModelIsFirst() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }
    
    func testWhenSelectionIndexIsOutOfBoundsThenSelectedTabViewModelIsNil() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        
        tabCollectionViewModel.select(at: 1)
        
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)
    }
    
    func testWhenSelectionIndexPointsToTabThenSelectedTabViewModelReturnsTheTab() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: 0)
        
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    // MARK: - Append

    func testWhenAppendNewTabIsCalledThenNewTabIsAlsoSelected() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        let index = tabCollectionViewModel.tabCollection.tabs.count
        tabCollectionViewModel.appendNewTab()
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: index))
    }

    func testAppendAfterSelected() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        tabCollectionViewModel.appendNewTab()

        let tab1 = tabCollection.tabs[0]
        let tab2 = tabCollection.tabs[1]

        let index = tabCollectionViewModel.tabCollection.tabs.count
        tabCollectionViewModel.appendNewTabAfterSelected()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: index))
        XCTAssertNotEqual(tabCollectionViewModel.selectedTabViewModel?.tab, tab1)
        XCTAssertNotEqual(tabCollectionViewModel.selectedTabViewModel?.tab, tab2)
    }

    // MARK: - Remove

    func testWhenRemoveIsCalledWithIndexOutOfBoundsThenNoTabIsRemoved() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        tabCollectionViewModel.remove(at: 1)

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
    }

    func testWhenTabIsRemovedAndSelectedTabHasHigherIndexThenSelectionIsPreserved() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)

        tabCollectionViewModel.appendNewTab()
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.remove(at: 0)

        XCTAssertEqual(selectedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func testWhenSelectedTabIsRemovedThenNextItemWithLowerIndexIsSelected() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.remove(at: 1)

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    func testWhenAllOtherTabsAreRemovedThenRemainedIsAlsoSelected() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        tabCollectionViewModel.removeOtherTabs(except: 0)

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    // MARK: - Duplicate

    func testWhenTabIsDuplicatedThenItsCopyHasHigherIndexByOne() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)

        tabCollectionViewModel.duplicateTab(at: 0)

        XCTAssert(firstTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    func testWhenTabIsDuplicatedThenItsCopyHasTheSameUrl() {
        let tabCollection = TabCollection()
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)
        firstTabViewModel?.tab.url = URL.duckDuckGo

        tabCollectionViewModel.duplicateTab(at: 0)

        XCTAssertEqual(firstTabViewModel?.tab.url, tabCollectionViewModel.tabViewModel(at: 1)?.tab.url)
    }

    
}
