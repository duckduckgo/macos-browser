//
//  TabCollectionViewModel.swift
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

import Foundation
import os.log
import Combine

protocol TabCollectionViewModelDelegate: AnyObject {

    func tabCollectionViewModelDidAppend(_ tabCollectionViewModel: TabCollectionViewModel, selected: Bool)
    func tabCollectionViewModelDidInsert(_ tabCollectionViewModel: TabCollectionViewModel, at index: Int, selected: Bool)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveTabAt removalIndex: Int,
                                andSelectTabAt selectionIndex: Int?)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didMoveTabAt index: Int, to newIndex: Int)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didSelectAt selectionIndex: Int?)
    func tabCollectionViewModelDidMultipleChanges(_ tabCollectionViewModel: TabCollectionViewModel)

}

// swiftlint:disable type_body_length
final class TabCollectionViewModel: NSObject {

    weak var delegate: TabCollectionViewModelDelegate?

    private(set) var tabCollection: TabCollection
    var pinnedTabsCollection: TabCollection {
        WindowControllersManager.shared.pinnedTabsManager.tabCollection
    }

    var numberOfTabs: Int {
        pinnedTabsCollection.tabs.count + tabCollection.tabs.count
    }

    var allTabs: [Tab] {
        pinnedTabsCollection.tabs + tabCollection.tabs
    }

    var changesEnabled = true

    private(set) var tabViewModels = [Tab: TabViewModel]()
    @Published private(set) var selectionIndex: Int? {
        didSet {
            updateSelectedTabViewModel()
        }
    }
    @Published private(set) var selectedTabViewModel: TabViewModel? {
        didSet {
            previouslySelectedTabViewModel = oldValue
        }
    }
    private weak var previouslySelectedTabViewModel: TabViewModel?

    // In a special occasion, we want to select the "parent" tab after closing the currently selected tab
    private var selectParentOnRemoval = false
    private var tabLazyLoader: TabLazyLoader<TabCollectionViewModel>?
    private var isTabLazyLoadingRequested: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(tabCollection: TabCollection, selectionIndex: Int = 0) {
        self.tabCollection = tabCollection
        super.init()

        subscribeToTabs()

        if tabCollection.tabs.isEmpty {
            appendNewTab(with: .homePage)
        }
        if self.selectionIndex != selectionIndex {
            self.selectionIndex = selectionIndex
        }
    }

    convenience override init() {
        let tabCollection = TabCollection()
        self.init(tabCollection: tabCollection)
    }

    func setUpLazyLoadingIfNeeded() {
        guard !isTabLazyLoadingRequested else {
            os_log("Lazy loading already requested in this session, skipping.", log: .tabLazyLoading, type: .debug)
            return
        }

        tabLazyLoader = TabLazyLoader(dataSource: self)
        isTabLazyLoadingRequested = true

        tabLazyLoader?.lazyLoadingDidFinishPublisher
            .sink { [weak self] _ in
                self?.tabLazyLoader = nil
                os_log("Disposed of Tab Lazy Loader", log: .tabLazyLoading, type: .debug)
            }
            .store(in: &cancellables)

        tabLazyLoader?.scheduleLazyLoading()
    }

    func tabViewModel(at index: Int) -> TabViewModel? {
        guard index >= 0, tabCollection.tabs.count > index else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return nil
        }

        let tab = tabCollection.tabs[index]
        return tabViewModels[tab]
    }

    // MARK: - Selection

    @discardableResult func selectRegularTab(at index: Int, forceChange: Bool = false) -> Bool {
        let indexIncludingPinnedTabs = pinnedTabsCollection.tabs.count + index
        return select(at: indexIncludingPinnedTabs)
    }

    @discardableResult func select(at index: Int, forceChange: Bool = false) -> Bool {
        guard changesEnabled || forceChange else { return false }
        guard index >= 0, index < numberOfTabs else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return false
        }

        selectionIndex = index
        selectParentOnRemoval = selectedTabViewModel === previouslySelectedTabViewModel && selectParentOnRemoval
        return true
    }

    @discardableResult func selectDisplayableTabIfPresent(_ content: Tab.TabContent) -> Bool {
        guard changesEnabled else { return false }
        guard content.isDisplayable else { return false }

        let isTabCurrentlySelected = selectedTabViewModel?.tab.content.matchesDisplayableTab(content) ?? false
        if isTabCurrentlySelected {
            return true
        }

        guard let index = tabCollection.tabs.firstIndex(where: { $0.content.matchesDisplayableTab(content) })
        else {
            return false
        }

        if selectRegularTab(at: index) {
            tabCollection.tabs[index].setContent(content)
            delegate?.tabCollectionViewModel(self, didSelectAt: index)
            return true
        }
        return false
    }

    func selectNext() {
        guard changesEnabled else { return }
        guard tabCollection.tabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = (selectionIndex + 1) % numberOfTabs
            select(at: newSelectionIndex)
            if newSelectionIndex >= pinnedTabsCollection.tabs.count {
                let indexInTabCollection = newSelectionIndex - pinnedTabsCollection.tabs.count
                delegate?.tabCollectionViewModel(self, didSelectAt: indexInTabCollection)
            }
        } else {
            select(at: 0)
            if pinnedTabsCollection.tabs.isEmpty {
                delegate?.tabCollectionViewModel(self, didSelectAt: 0)
            }
        }
    }

    func selectPrevious() {
        guard changesEnabled else { return }
        guard tabCollection.tabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = selectionIndex - 1 >= 0 ? selectionIndex - 1 : numberOfTabs - 1
            select(at: newSelectionIndex)
            if newSelectionIndex >= pinnedTabsCollection.tabs.count {
                let indexInTabCollection = newSelectionIndex - pinnedTabsCollection.tabs.count
                delegate?.tabCollectionViewModel(self, didSelectAt: indexInTabCollection)
            }
        } else {
            select(at: numberOfTabs - 1)
            if !tabCollection.tabs.isEmpty {
                delegate?.tabCollectionViewModel(self, didSelectAt: tabCollection.tabs.count - 1)
            }
        }
    }

    // MARK: - Addition

    func appendNewTab(with content: Tab.TabContent = .homePage, selected: Bool = true, forceChange: Bool = false) {
        if selectDisplayableTabIfPresent(content) {
            return
        }
        append(tab: Tab(content: content), selected: selected, forceChange: forceChange)
    }

    func append(tab: Tab, selected: Bool = true, forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.append(tab: tab)

        if selected {
            select(at: numberOfTabs - 1, forceChange: forceChange)
            delegate?.tabCollectionViewModelDidAppend(self, selected: true)
        } else {
            delegate?.tabCollectionViewModelDidAppend(self, selected: false)
        }

        if selected {
            self.selectParentOnRemoval = true
        }
    }

    func append(tabs: [Tab]) {
        guard changesEnabled else { return }

        tabs.forEach {
            tabCollection.append(tab: $0)
        }
        let newSelectionIndex = numberOfTabs - 1
        select(at: newSelectionIndex)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func insert(tab: Tab, at index: Int = 0, selected: Bool = true) {
        guard changesEnabled else { return }

        tabCollection.insert(tab: tab, at: index)
        if selected {
            let indexIncludingPinnedTabs = pinnedTabsCollection.tabs.count + index
            select(at: indexIncludingPinnedTabs)
        }
        delegate?.tabCollectionViewModelDidInsert(self, at: index, selected: selected)

        if selected {
            self.selectParentOnRemoval = true
        }
    }

    func insertChild(tab: Tab, selected: Bool) {
        guard changesEnabled else { return }
        guard let parentTab = tab.parentTab,
              let parentTabIndex = tabCollection.tabs.firstIndex(where: { $0 === parentTab }) else {
            os_log("TabCollection: No parent tab", type: .error)
            return
        }

        // Insert at the end of the child tabs
        var newIndex = parentTabIndex + 1
        while tabCollection.tabs[safe: newIndex]?.parentTab === parentTab { newIndex += 1 }
        insert(tab: tab, at: newIndex, selected: selected)
    }

    // MARK: - Removal

    func remove(at index: Int, published: Bool = true) {
        guard changesEnabled, let (tabCollection, indexInCollection) = tabCollection(for: index) else { return }

        let parentTab = tabCollection.tabs[indexInCollection].parentTab
        guard tabCollection.remove(at: indexInCollection, published: published) else { return }

        didRemoveTab(at: index, withParent: parentTab, from: tabCollection, indexInCollection: indexInCollection)
    }

    private func tabCollection(for index: Int) -> (TabCollection, Int)? {
        if pinnedTabsCollection.tabs.indices.contains(index) {
            return (pinnedTabsCollection, index)
        }
        let indexWithoutPinnedTabs = index - pinnedTabsCollection.tabs.count
        if tabCollection.tabs.indices.contains(indexWithoutPinnedTabs) {
            return (tabCollection, indexWithoutPinnedTabs)
        }
        return nil
    }

    private func didRemoveTab(at index: Int, withParent parentTab: Tab?, from collection: TabCollection, indexInCollection: Int) {
        defer {
            if collection === tabCollection {
                delegate?.tabCollectionViewModel(self, didRemoveTabAt: indexInCollection, andSelectTabAt: self.selectionIndex)
            }
        }

        guard numberOfTabs > 0 else {
            selectionIndex = nil
            return
        }

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        let newSelectionIndex: Int
        if selectionIndex == index,
           selectParentOnRemoval,
           let parentTab = parentTab,
           let parentTabIndex = allTabs.firstIndex(of: parentTab) {
            // Select parent tab
            newSelectionIndex = parentTabIndex
        } else if selectionIndex == index,
                  let parentTab = parentTab,
                  let leftTab = allTabs[safe: index - 1],
                  let rightTab = allTabs[safe: index],
                  rightTab.parentTab !== parentTab && (leftTab.parentTab === parentTab || leftTab === parentTab) {
            // Select parent tab on left or another child tab on left instead of the tab on right
            newSelectionIndex = max(selectionIndex - 1, 0)
        } else if selectionIndex > index {
            newSelectionIndex = max(selectionIndex - 1, 0)
        } else {
            newSelectionIndex = max(min(selectionIndex, numberOfTabs - 1), 0)
        }
        select(at: newSelectionIndex)
    }

    func moveRegularTab(at fromIndex: Int, to otherViewModel: TabCollectionViewModel, at toIndex: Int) {
        guard changesEnabled else { return }

        let parentTab = tabCollection.tabs[safe: fromIndex]?.parentTab

        guard tabCollection.moveTab(at: fromIndex, to: otherViewModel.tabCollection, at: toIndex) else { return }

        didRemoveTab(at: fromIndex, withParent: parentTab, from: tabCollection, indexInCollection: fromIndex)

        otherViewModel.select(at: toIndex)
        otherViewModel.delegate?.tabCollectionViewModelDidInsert(otherViewModel, at: toIndex, selected: true)
        otherViewModel.selectParentOnRemoval = true
    }

    func removeAllTabs(except exceptionIndex: Int? = nil) {
        guard changesEnabled else { return }

        tabCollection.removeAll(andAppend: exceptionIndex.map { tabCollection.tabs[$0] })

        if exceptionIndex != nil {
            select(at: 0)
        } else {
            selectionIndex = nil
        }
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabs(after index: Int) {
        guard changesEnabled else { return }

        tabCollection.removeTabs(after: index)

        if !tabCollection.tabs.indices.contains(selectionIndex ?? -1) {
            selectionIndex = tabCollection.tabs.indices.last
        }

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeAllTabsAndAppendNew(forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.removeAll(andAppend: Tab(content: .homePage))
        select(at: 0, forceChange: forceChange)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabsAndAppendNew(at indexSet: IndexSet, forceChange: Bool = false) {
        guard !indexSet.isEmpty, changesEnabled || forceChange else { return }
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        tabCollection.removeTabs(at: indexSet)
        if tabCollection.tabs.isEmpty {
            tabCollection.append(tab: Tab(content: .homePage))
            select(at: 0, forceChange: forceChange)
        } else {
            let selectionDiff = indexSet.reduce(0) { result, index in
                if index < selectionIndex {
                    return result + 1
                } else {
                    return result
                }
            }

            select(at: max(min(selectionIndex - selectionDiff, tabCollection.tabs.count - 1), 0), forceChange: forceChange)
        }
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func remove(ownerOf webView: WebView) {
        guard changesEnabled else { return }

        let webViews = allTabs.map { $0.webView }
        guard let index = webViews.firstIndex(of: webView) else {
            os_log("TabCollection: Failed to get index of the tab", type: .error)
            return
        }

        self.remove(at: index)
    }

    func removeSelected() {
        guard changesEnabled else { return }

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }

        self.remove(at: selectionIndex)
    }

    // MARK: - Others

    func duplicateTab(at index: Int) {
        guard changesEnabled else { return }

        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return
        }

        let tab = tabCollection.tabs[index]
        let tabCopy = Tab(content: tab.content, sessionStateData: tab.sessionStateData)
        let newIndex = index + 1

        tabCollection.insert(tab: tabCopy, at: newIndex)
        select(at: newIndex + pinnedTabsCollection.tabs.count)

        delegate?.tabCollectionViewModelDidInsert(self, at: newIndex, selected: true)
    }

    // TODO
    func moveTab(at index: Int, to newIndex: Int) {
        guard changesEnabled else { return }

        tabCollection.moveTab(at: index, to: newIndex)
        select(at: newIndex + pinnedTabsCollection.tabs.count)

        delegate?.tabCollectionViewModel(self, didMoveTabAt: index, to: newIndex)
    }

    // TODO
    func replaceTab(at index: Int, with tab: Tab, forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.replaceTab(at: index, with: tab)

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }
        select(at: selectionIndex + pinnedTabsCollection.tabs.count, forceChange: forceChange)
    }

    private func subscribeToTabs() {
        tabCollection.$tabs.sink { [weak self] newTabs in
            guard let self = self else { return }

            let new = Set(newTabs)
            let old = Set(self.tabViewModels.keys)

            self.removeTabViewModels(old.subtracting(new))
            self.addTabViewModels(new.subtracting(old))
        } .store(in: &cancellables)
    }

    private func removeTabViewModels(_ removed: Set<Tab>) {
        for tab in removed {
            tabViewModels[tab] = nil
        }
    }

    private func addTabViewModels(_ added: Set<Tab>) {
        for tab in added {
            tabViewModels[tab] = TabViewModel(tab: tab)
        }
    }

    private func updateSelectedTabViewModel() {
        guard let selectionIndex = selectionIndex, let (tabCollection, indexInCollection) = tabCollection(for: selectionIndex) else {
            selectedTabViewModel = nil
            return
        }

        var selectedTabViewModel: TabViewModel?

        switch tabCollection {
        case self.tabCollection:
            selectedTabViewModel = tabViewModel(at: indexInCollection)
        case pinnedTabsCollection:
            selectedTabViewModel = WindowControllersManager.shared.pinnedTabsManager.tabViewModel(at: selectionIndex)
        default:
            break
        }

        selectedTabViewModel?.tab.lastSelectedAt = Date()
        self.selectedTabViewModel = selectedTabViewModel
    }

}
// swiftlint:enable type_body_length
