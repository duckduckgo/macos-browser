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

/**
 * The delegate callbacks are triggered for events related to unpinned tabs only.
 */
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

final class TabCollectionViewModel: NSObject {

    weak var delegate: TabCollectionViewModelDelegate?

    /// Local tabs collection
    private(set) var tabCollection: TabCollection

    /// Pinned tabs collection (provided via `PinnedTabsManager` instance).
    var pinnedTabsCollection: TabCollection {
        pinnedTabsManager.tabCollection
    }

    var allTabsCount: Int {
        pinnedTabsCollection.tabs.count + tabCollection.tabs.count
    }

    var changesEnabled = true

    private(set) var pinnedTabsManager: PinnedTabsManager

    /**
     * Contains view models for local tabs
     *
     * Pinned tabs' view models are shared between windows
     * and are available through `pinnedTabsManager`.
     */
    private(set) var tabViewModels = [Tab: TabViewModel]()

    @Published private(set) var selectionIndex: TabIndex? {
        didSet {
            updateSelectedTabViewModel()
        }
    }

    /// Can point to a local or pinned tab view model.
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

    private var shouldBlockPinnedTabsManagerUpdates: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(
        tabCollection: TabCollection,
        selectionIndex: Int = 0,
        pinnedTabsManager: PinnedTabsManager = WindowControllersManager.shared.pinnedTabsManager
    ) {
        self.tabCollection = tabCollection
        self.pinnedTabsManager = pinnedTabsManager
        super.init()

        subscribeToTabs()
        subscribeToPinnedTabsManager()

        if tabCollection.tabs.isEmpty {
            appendNewTab(with: .homePage)
        }
        self.selectionIndex = .unpinned(selectionIndex)
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

    @discardableResult func select(at index: TabIndex, forceChange: Bool = false) -> Bool {
        switch index {
        case .unpinned(let i):
            return selectUnpinnedTab(at: i, forceChange: forceChange)
        case .pinned(let i):
            return selectPinnedTab(at: i, forceChange: forceChange)
        }
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

        if selectUnpinnedTab(at: index) {
            tabCollection.tabs[index].setContent(content)
            delegate?.tabCollectionViewModel(self, didSelectAt: index)
            return true
        }
        return false
    }

    func selectNext() {
        guard changesEnabled else { return }
        guard allTabsCount > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        let newSelectionIndex = selectionIndex?.next(in: self) ?? .first(in: self)
        select(at: newSelectionIndex)
        if newSelectionIndex.isUnpinnedTab {
            delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex.item)
        }
    }

    func selectPrevious() {
        guard changesEnabled else { return }
        guard allTabsCount > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        let newSelectionIndex = selectionIndex?.previous(in: self) ?? .last(in: self)
        select(at: newSelectionIndex)
        if newSelectionIndex.isUnpinnedTab {
            delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex.item)
        }
    }

    @discardableResult private func selectUnpinnedTab(at index: Int, forceChange: Bool = false) -> Bool {
        guard changesEnabled || forceChange else { return false }
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return false
        }

        selectionIndex = .unpinned(index)
        selectParentOnRemoval = selectedTabViewModel === previouslySelectedTabViewModel && selectParentOnRemoval
        return true
    }

    @discardableResult private func selectPinnedTab(at index: Int, forceChange: Bool = false) -> Bool {
        guard changesEnabled || forceChange else { return false }
        guard index >= 0, index < pinnedTabsCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return false
        }

        selectionIndex = .pinned(index)
        selectParentOnRemoval = selectedTabViewModel === previouslySelectedTabViewModel && selectParentOnRemoval
        return true
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
            selectUnpinnedTab(at: tabCollection.tabs.count - 1, forceChange: forceChange)
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
        let newSelectionIndex = tabCollection.tabs.count - 1
        selectUnpinnedTab(at: newSelectionIndex)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func insert(tab: Tab, at index: TabIndex = .unpinned(0), selected: Bool = true) {
        guard changesEnabled else { return }

        let tabCollection = tabCollection(for: index)
        tabCollection.insert(tab: tab, at: index.item)
        if selected {
            select(at: index)
        }
        if index.isUnpinnedTab {
            delegate?.tabCollectionViewModelDidInsert(self, at: index.item, selected: selected)
        }

        if selected {
            self.selectParentOnRemoval = true
        }
    }

    func insertChild(tab: Tab, selected: Bool) {
        guard changesEnabled else { return }
        guard let parentTab = tab.parentTab,
              let parentTabIndex = indexInAllTabs(of: parentTab) else {
            os_log("TabCollection: No parent tab", type: .error)
            return
        }

        // Insert at the end of the child tabs
        var newIndex = parentTabIndex.isPinnedTab ? 0 : parentTabIndex.item + 1
        while tabCollection.tabs[safe: newIndex]?.parentTab === parentTab { newIndex += 1 }
        insert(tab: tab, at: .unpinned(newIndex), selected: selected)
    }

    // MARK: - Removal

    func remove(at index: TabIndex, published: Bool = true) {
        switch index {
        case .unpinned(let i):
            return removeUnpinnedTab(at: i, published: published)
        case .pinned(let i):
            return removePinnedTab(at: i, published: published)
        }
    }

    private func removeUnpinnedTab(at index: Int, published: Bool = true) {
        guard changesEnabled else { return }

        let parentTab = tabCollection.tabs[safe: index]?.parentTab
        guard tabCollection.remove(at: index, published: published) else { return }

        didRemoveTab(at: .unpinned(index), withParent: parentTab)
    }

    private func removePinnedTab(at index: Int, published: Bool = true) {
        guard changesEnabled else { return }
        shouldBlockPinnedTabsManagerUpdates = true
        defer {
            shouldBlockPinnedTabsManagerUpdates = false
        }
        guard pinnedTabsManager.unpinTab(at: index, published: published) != nil else { return }

        didRemoveTab(at: .pinned(index), withParent: nil)
    }

    private func didRemoveTab(at index: TabIndex, withParent parentTab: Tab?) {

        func notifyDelegate() {
            if index.isUnpinnedTab {
                let newSelectionIndex = self.selectionIndex?.isUnpinnedTab == true ? self.selectionIndex?.item : nil
                delegate?.tabCollectionViewModel(self, didRemoveTabAt: index.item, andSelectTabAt: newSelectionIndex)
            }
        }

        guard index.isPinnedTab || !pinnedTabsCollection.tabs.isEmpty || tabCollection.tabs.count > 0 else {
            selectionIndex = nil
            notifyDelegate()
            return
        }

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
            notifyDelegate()
            return
        }

        let newSelectionIndex: TabIndex
        if selectionIndex == index,
           selectParentOnRemoval,
           let parentTab = parentTab,
           let parentTabIndex = indexInAllTabs(of: parentTab) {
            // Select parent tab
            newSelectionIndex = parentTabIndex
        } else if selectionIndex == index,
                  let parentTab = parentTab,
                  let leftTab = tab(at: index.previous(in: self)),
                  let rightTab = tab(at: index),
                  rightTab.parentTab !== parentTab && (leftTab.parentTab === parentTab || leftTab === parentTab) {
            // Select parent tab on left or another child tab on left instead of the tab on right
            newSelectionIndex = .unpinned(max(0, selectionIndex.item - 1))
        } else if selectionIndex > index, selectionIndex.isInSameSection(as: index) {
            newSelectionIndex = selectionIndex.previous(in: self)
        } else {
            newSelectionIndex = selectionIndex.sanitized(for: self)
        }

        notifyDelegate()
        select(at: newSelectionIndex)
    }

    func moveTab(at fromIndex: Int, to otherViewModel: TabCollectionViewModel, at toIndex: Int) {
        guard changesEnabled else { return }

        let parentTab = tabCollection.tabs[safe: fromIndex]?.parentTab

        guard tabCollection.moveTab(at: fromIndex, to: otherViewModel.tabCollection, at: toIndex) else { return }

        didRemoveTab(at: .unpinned(fromIndex), withParent: parentTab)

        otherViewModel.selectUnpinnedTab(at: toIndex)
        otherViewModel.delegate?.tabCollectionViewModelDidInsert(otherViewModel, at: toIndex, selected: true)
        otherViewModel.selectParentOnRemoval = true
    }

    func removeAllTabs(except exceptionIndex: Int? = nil) {
        guard changesEnabled else { return }

        tabCollection.removeAll(andAppend: exceptionIndex.map { tabCollection.tabs[$0] })

        if exceptionIndex != nil {
            selectUnpinnedTab(at: 0)
        } else {
            selectionIndex = nil
        }
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabs(after index: Int) {
        guard changesEnabled else { return }

        tabCollection.removeTabs(after: index)

        if let currentSelection = selectionIndex, currentSelection.isUnpinnedTab, !tabCollection.tabs.indices.contains(currentSelection.item) {
            selectionIndex = .unpinned(tabCollection.tabs.count - 1)
        }

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeAllTabsAndAppendNew(forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.removeAll(andAppend: Tab(content: .homePage))
        selectUnpinnedTab(at: 0, forceChange: forceChange)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabsAndAppendNew(at indexSet: IndexSet, forceChange: Bool = false) {
        guard !indexSet.isEmpty, changesEnabled || forceChange else { return }
        guard let selectionIndex = selectionIndex?.item else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        tabCollection.removeTabs(at: indexSet)
        if tabCollection.tabs.isEmpty {
            tabCollection.append(tab: Tab(content: .homePage))
            selectUnpinnedTab(at: 0, forceChange: forceChange)
        } else {
            let selectionDiff = indexSet.reduce(0) { result, index in
                if index < selectionIndex {
                    return result + 1
                } else {
                    return result
                }
            }

            selectUnpinnedTab(at: max(min(selectionIndex - selectionDiff, tabCollection.tabs.count - 1), 0), forceChange: forceChange)
        }
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func remove(ownerOf webView: WebView) {
        guard changesEnabled else { return }

        if let index = tabCollection.tabs.firstIndex(where: { $0.webView === webView }) {
            remove(at: .unpinned(index))
        } else if let index = pinnedTabsCollection.tabs.firstIndex(where: { $0.webView === webView }) {
            remove(at: .pinned(index))
        } else {
            os_log("TabCollection: Failed to get index of the tab", type: .error)
        }
    }

    func removeSelected() {
        guard changesEnabled else { return }

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }

        remove(at: selectionIndex)
    }

    // MARK: - Others

    func duplicateTab(at tabIndex: TabIndex) {
        guard changesEnabled else { return }

        guard let tab = tab(at: tabIndex) else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return
        }

        let tabCopy = Tab(content: tab.content, sessionStateData: tab.sessionStateData)
        let newIndex = tabIndex.makeNext()

        tabCollection(for: tabIndex).insert(tab: tabCopy, at: newIndex.item)
        select(at: newIndex)

        if newIndex.isUnpinnedTab {
            delegate?.tabCollectionViewModelDidInsert(self, at: newIndex.item, selected: true)
        }
    }

    func pinTab(at index: Int) {
        guard changesEnabled else { return }

        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return
        }

        let tab = tabCollection.tabs[index]

        pinnedTabsManager.pin(tab)
        removeUnpinnedTab(at: index, published: false)
        selectPinnedTab(at: pinnedTabsCollection.tabs.count - 1)
    }

    func unpinTab(at index: Int) {
        guard changesEnabled else { return }
        shouldBlockPinnedTabsManagerUpdates = true
        defer {
            shouldBlockPinnedTabsManagerUpdates = false
        }

        guard let tab = pinnedTabsManager.unpinTab(at: index, published: false) else {
            os_log("Unable to unpin a tab", type: .error)
            return
        }

        insert(tab: tab)
    }

    private func handleTabUnpinnedInAnotherTabCollectionViewModel(at index: Int) {
        if selectionIndex == .pinned(index) {
            didRemoveTab(at: .pinned(index), withParent: nil)
        }
    }

    func moveTab(at index: Int, to newIndex: Int) {
        guard changesEnabled else { return }

        tabCollection.moveTab(at: index, to: newIndex)
        selectUnpinnedTab(at: newIndex)

        delegate?.tabCollectionViewModel(self, didMoveTabAt: index, to: newIndex)
    }

    func replaceTab(at index: TabIndex, with tab: Tab, forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        let tabCollection = tabCollection(for: index)
        tabCollection.replaceTab(at: index.item, with: tab)

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }
        select(at: selectionIndex, forceChange: forceChange)
    }

    private func subscribeToPinnedTabsManager() {
        pinnedTabsManager.didUnpinTabPublisher
            .filter { [weak self] _ in self?.shouldBlockPinnedTabsManagerUpdates == false }
            .sink { [weak self] index in
                self?.handleTabUnpinnedInAnotherTabCollectionViewModel(at: index)
            }
            .store(in: &cancellables)
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
        guard let selectionIndex = selectionIndex else {
            selectedTabViewModel = nil
            return
        }

        let tabCollection = self.tabCollection(for: selectionIndex)
        var selectedTabViewModel: TabViewModel?

        switch tabCollection {
        case self.tabCollection:
            selectedTabViewModel = tabViewModel(at: selectionIndex.item)
        case pinnedTabsCollection:
            selectedTabViewModel = pinnedTabsManager.tabViewModel(at: selectionIndex.item)
        default:
            break
        }

        selectedTabViewModel?.tab.lastSelectedAt = Date()
        self.selectedTabViewModel = selectedTabViewModel
    }
}

extension TabCollectionViewModel {

    private func tabCollection(for selection: TabIndex) -> TabCollection {
        switch selection {
        case .unpinned:
            return tabCollection
        case .pinned:
            return pinnedTabsCollection
        }
    }

    private func indexInAllTabs(of tab: Tab) -> TabIndex? {
        if let index = pinnedTabsCollection.tabs.firstIndex(of: tab) {
            return .pinned(index)
        }
        if let index = tabCollection.tabs.firstIndex(of: tab) {
            return .unpinned(index)
        }
        return nil
    }

    private func tab(at tabIndex: TabIndex) -> Tab? {
        switch tabIndex {
        case .pinned(let index):
            return pinnedTabsCollection.tabs[safe: index]
        case .unpinned(let index):
            return tabCollection.tabs[safe: index]
        }
    }

}
