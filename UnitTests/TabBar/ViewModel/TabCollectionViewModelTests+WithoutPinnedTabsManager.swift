//
//  TabCollectionViewModelTests+WithoutPinnedTabsManager.swift
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

// MARK: - Tests for TabCollectionViewModel without PinnedTabsManager (popup windows)

extension TabCollectionViewModelTests {

    override func setUp() {
        customAssert = { _, _, _, _ in }
        customAssertionFailure = { _, _, _ in }
    }

    override func tearDown() {
        customAssert = nil
        customAssertionFailure = nil
    }

    // MARK: - TabViewModel

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabViewModelIsCalledWithIndexOutOfBoundsThenNilIsReturned() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssertNil(tabCollectionViewModel.tabViewModel(at: 1))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabViewModelIsCalledThenAppropriateTabViewModelIsReturned() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssertEqual(tabCollectionViewModel.tabViewModel(at: 0)?.tab,
                       tabCollectionViewModel.tabCollection.tabs[0])
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabViewModelIsCalledWithSameIndexThenTheResultHasSameIdentity() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssert(tabCollectionViewModel.tabViewModel(at: 0) === tabCollectionViewModel.tabViewModel(at: 0))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabViewModelIsInitializedWithoutTabsThenNewHomePageTabIsCreated() {
        let tabCollection = TabCollection()
        XCTAssertTrue(tabCollection.tabs.isEmpty)

        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: TabCollection())

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs[0].content, .newtab)
    }

    // MARK: - Select

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabCollectionViewModelIsInitializedThenSelectedTabViewModelIsFirst() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenSelectionIndexIsOutOfBoundsThenSelectedTabViewModelIsNil() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.select(at: .unpinned(1))
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)

        tabCollectionViewModel.select(at: .pinned(0))
        XCTAssertNil(tabCollectionViewModel.selectedTabViewModel)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenSelectionIndexPointsToTabThenSelectedTabViewModelReturnsTheTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenSelectNextIsCalledThenNextTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenLastTabIsSelectedThenSelectNextChangesSelectionToFirstOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.selectNext()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenSelectPreviousIsCalledThenPreviousTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenFirstTabIsSelectedThenSelectPreviousChangesSelectionToLastOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.selectPrevious()

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenPreferencesTabIsPresentThenSelectDisplayableTabIfPresentSelectsPreferencesTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .anySettingsPane))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .newtab))
        tabCollectionViewModel.select(at: .unpinned(0))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.anySettingsPane))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenPreferencesTabIsPresentThenOpeningPreferencesWithDifferentPaneUpdatesPaneOnExistingTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .settings(pane: .appearance)))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .newtab))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.settings(pane: .general)))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab.content, .settings(pane: .general))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenPreferencesTabIsPresentThenOpeningPreferencesWithAnyPaneDoesNotUpdatePaneOnExistingTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .settings(pane: .appearance)))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .newtab))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.anySettingsPane))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab.content, .settings(pane: .appearance))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenBookmarksTabIsPresentThenSelectDisplayableTabIfPresentSelectsBookmarksTab() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .bookmarks))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .newtab))
        tabCollectionViewModel.select(at: .unpinned(0))

        XCTAssertTrue(tabCollectionViewModel.selectDisplayableTabIfPresent(.bookmarks))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_SelectDisplayableTabDoesNotChangeSelectionIfDisplayableTabIsNotPresent() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .newtab))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .newtab))
        tabCollectionViewModel.select(at: .unpinned(2))

        XCTAssertFalse(tabCollectionViewModel.selectDisplayableTabIfPresent(.bookmarks))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 2))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_SelectDisplayableTabDoesNotChangeSelectionIfDisplayableTabTypeDoesNotMatch() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .bookmarks))
        tabCollectionViewModel.tabCollection.append(tab: .init(content: .newtab))
        tabCollectionViewModel.select(at: .unpinned(2))

        XCTAssertFalse(tabCollectionViewModel.selectDisplayableTabIfPresent(.anySettingsPane))
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 2))
    }

    // MARK: - Append

    @MainActor
    func test_WithoutPinnedTabsManager_WhenAppendNewTabIsCalledThenNewTabIsAlsoSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let index = tabCollectionViewModel.tabCollection.tabs.count
        tabCollectionViewModel.appendNewTab()
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: index))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabIsAppendedWithSelectedAsFalseThenSelectionIsPreserved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel

        tabCollectionViewModel.append(tab: Tab(), selected: false)

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === selectedTabViewModel)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabIsAppendedWithSelectedAsTrueThenNewTabIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.append(tab: Tab(), selected: true)
        let lastTabViewModel = tabCollectionViewModel.tabViewModel(at: tabCollectionViewModel.tabCollection.tabs.count - 1)

        XCTAssert(tabCollectionViewModel.selectedTabViewModel === lastTabViewModel)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenMultipleTabsAreAppendedThenTheLastOneIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let lastTab = Tab()
        tabCollectionViewModel.append(tabs: [Tab(), lastTab])

        XCTAssert(tabCollectionViewModel.selectedTabViewModel?.tab === lastTab)
    }

    // MARK: - Insert

    @MainActor
    func test_WithoutPinnedTabsManager_WhenInsertNewTabIsCalledThenNewTabIsAlsoSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))
        XCTAssertNotNil(tabCollectionViewModel.selectedTabViewModel)
        tabCollectionViewModel.insertNewTab(after: tabCollectionViewModel.selectedTabViewModel!.tab)
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenInsertChildAndParentIsntPartOfTheTabCollection_ThenNoChildIsInserted() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let parentTab = Tab()
        let tab = Tab(content: .none, parentTab: parentTab)
        tabCollectionViewModel.insert(tab, selected: false)

        XCTAssert(tab !== tabCollectionViewModel.tabViewModel(at: 0)?.tab)
        XCTAssert(tabCollectionViewModel.tabCollection.tabs.count == 1)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenInsertChildAndNoOtherChildTabIsNearParent_ThenTabIsInsertedRightNextToParent() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        let parentTab = Tab()
        tabCollectionViewModel.append(tab: parentTab)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insert(tab, selected: false)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 2)?.tab)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenInsertChildAndOtherChildTabsAreNearParent_ThenTabIsInsertedAtTheEndOfChildList() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()

        let parentTab = Tab()
        tabCollectionViewModel.insert(parentTab, at: .unpinned(1), selected: true)

        tabCollectionViewModel.insert(Tab(parentTab: parentTab), selected: false)
        tabCollectionViewModel.insert(Tab(parentTab: parentTab), selected: false)
        tabCollectionViewModel.insert(Tab(parentTab: parentTab), selected: false)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insert(tab, selected: true)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 5)?.tab)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenInsertChildAndParentIsLast_ThenTabIsAppendedAtTheEnd() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()

        let parentTab = Tab()
        tabCollectionViewModel.insert(parentTab, at: .unpinned(1), selected: true)

        let tab = Tab(parentTab: parentTab)
        tabCollectionViewModel.insert(tab, selected: false)

        XCTAssert(tab === tabCollectionViewModel.tabViewModel(at: 2)?.tab)
    }

    // MARK: - Insert or Append

    @MainActor
    func test_WithoutPinnedTabsManager_WhenInsertOrAppendCalledPreferencesAreRespected() {
        let persistor = MockTabsPreferencesPersistor()
        var tabCollectionViewModel = TabCollectionViewModel(tabCollection: TabCollection(), pinnedTabsManager: nil,
                                                            tabsPreferences: TabsPreferences(persistor: persistor))

        let index = tabCollectionViewModel.tabCollection.tabs.count
        tabCollectionViewModel.insertOrAppendNewTab()
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: index))

        persistor.newTabPosition = .nextToCurrent
        tabCollectionViewModel = TabCollectionViewModel(tabCollection: TabCollection(), pinnedTabsManager: nil,
                                                            tabsPreferences: TabsPreferences(persistor: persistor))

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.select(at: .unpinned(0))
        XCTAssertNotNil(tabCollectionViewModel.selectedTabViewModel)
        tabCollectionViewModel.insertOrAppendNewTab()
        XCTAssert(tabCollectionViewModel.selectedTabViewModel === tabCollectionViewModel.tabViewModel(at: 1))
    }

    // MARK: - Remove

    @MainActor
    func test_WithoutPinnedTabsManager_WhenRemoveIsCalledWithIndexOutOfBoundsThenNoTabIsRemoved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.remove(at: .unpinned(1))

        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 1)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabIsRemovedAndSelectedTabHasHigherIndexThenSelectionIsPreserved() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.remove(at: .unpinned(0))

        XCTAssertEqual(selectedTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenSelectedTabIsRemovedThenNextItemWithLowerIndexIsSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.remove(at: .unpinned(1))

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenAllOtherTabsAreRemovedThenRemainedIsAlsoSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTab = tabCollectionViewModel.tabCollection.tabs[0]

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        tabCollectionViewModel.removeAllTabs(except: 0)

        XCTAssertEqual(firstTab, tabCollectionViewModel.selectedTabViewModel?.tab)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenLastTabIsRemoved_ThenSelectionIsNil() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.remove(at: .unpinned(0))

        XCTAssertNil(tabCollectionViewModel.selectionIndex)
        XCTAssertEqual(tabCollectionViewModel.tabCollection.tabs.count, 0)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenNoTabIsSelectedAndTabIsRemoved_ThenSelectionStaysEmpty() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()

        // Clear selection
        tabCollectionViewModel.select(at: .unpinned(-1))

        tabCollectionViewModel.remove(at: .unpinned(1))

        XCTAssertNil(tabCollectionViewModel.selectionIndex)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenChildTabIsInsertedAndRemoved_ThenParentIsSelectedBack() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let parentTab = tabCollectionViewModel.tabCollection.tabs[0]
        let childTab1 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab1, selected: false)
        let childTab2 = Tab(parentTab: parentTab)
        tabCollectionViewModel.append(tab: childTab2, selected: true)

        tabCollectionViewModel.remove(at: .unpinned(2))

        XCTAssertEqual(tabCollectionViewModel.selectedTabViewModel?.tab, parentTab)
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenChildTabOnLeftHasTheSameParentAndTabOnRightDont_ThenTabOnLeftIsSelectedAfterRemoval() {
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

    @MainActor
    func test_WithoutPinnedTabsManager_RemoveSelected() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()

        tabCollectionViewModel.appendNewTab()
        tabCollectionViewModel.appendNewTab()
        let selectedTab = tabCollectionViewModel.selectedTabViewModel?.tab

        tabCollectionViewModel.removeSelected()

        XCTAssertFalse(tabCollectionViewModel.tabCollection.tabs.contains(selectedTab!))
    }

    // MARK: - Duplicate

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabIsDuplicatedThenItsCopyHasHigherIndexByOne() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)

        tabCollectionViewModel.duplicateTab(at: .unpinned(0))

        XCTAssert(firstTabViewModel === tabCollectionViewModel.tabViewModel(at: 0))
    }

    @MainActor
    func test_WithoutPinnedTabsManager_WhenTabIsDuplicatedThenItsCopyHasTheSameUrl() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)
        firstTabViewModel?.tab.url = URL.duckDuckGo

        tabCollectionViewModel.duplicateTab(at: .unpinned(0))

        XCTAssertEqual(firstTabViewModel?.tab.url, tabCollectionViewModel.tabViewModel(at: 1)?.tab.url)
    }

    // MARK: - Publishers

    @MainActor
    func test_WithoutPinnedTabsManager_WhenSelectionIndexIsUpdatedWithTheSameValueThenSelectedTabViewModelIsOnlyPublishedOnce() {
        let tabCollectionViewModel = TabCollectionViewModel.aTabCollectionViewModel()
        let firstTabViewModel = tabCollectionViewModel.tabViewModel(at: 0)
        firstTabViewModel?.tab.url = URL.duckDuckGo

        var events: [TabViewModel?] = []
        let cancellable = tabCollectionViewModel.$selectedTabViewModel
            .sink { tabViewModel in
                events.append(tabViewModel)
            }

        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.select(at: .unpinned(0))
        tabCollectionViewModel.select(at: .unpinned(0))

        cancellable.cancel()

        XCTAssertEqual(events.count, 1)
        XCTAssertIdentical(events[0], tabCollectionViewModel.selectedTabViewModel)
    }
}

fileprivate extension TabCollectionViewModel {

    static func aTabCollectionViewModel() -> TabCollectionViewModel {
        let tabCollection = TabCollection()
        return TabCollectionViewModel(tabCollection: tabCollection, pinnedTabsManager: nil)
    }
}
