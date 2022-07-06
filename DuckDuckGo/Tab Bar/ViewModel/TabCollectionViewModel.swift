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

enum TabIndex: Equatable, Comparable {
    case pinned(Int), regular(Int)

    var index: Int {
        switch self {
        case .pinned(let index), .regular(let index):
            return index
        }
    }

    var isPinnedTab: Bool {
        if case .pinned = self {
            return true
        }
        return false
    }

    var isRegularTab: Bool {
        !isPinnedTab
    }

    var next: Self {
        switch self {
        case let .pinned(index):
            return .pinned(index + 1)
        case let .regular(index):
            return .regular(index + 1)
        }
    }

    static func < (_ lhs: TabIndex, _ rhs: TabIndex) -> Bool {
        switch (lhs, rhs) {
        case (.pinned, .regular):
            return true
        case (.regular, .pinned):
            return false
        default:
            return lhs.index < rhs.index
        }
    }
}

// swiftlint:disable type_body_length
final class TabCollectionViewModel: NSObject {

    weak var delegate: TabCollectionViewModelDelegate?

    private(set) var tabCollection: TabCollection
    var pinnedTabsCollection: TabCollection {
        pinnedTabsManager.tabCollection
    }

    var numberOfTabs: Int {
        pinnedTabsCollection.tabs.count + tabCollection.tabs.count
    }

    var allTabs: [Tab] {
        pinnedTabsCollection.tabs + tabCollection.tabs
    }

    var changesEnabled = true

    private(set) var tabViewModels = [Tab: TabViewModel]()
    @Published private(set) var selectionIndex: TabIndex? {
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

    private let pinnedTabsManager: PinnedTabsManager
    private var shouldBlockPinnedTabsManagerSubscriptions: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(
        tabCollection: TabCollection,
        selectionIndex: TabIndex = .regular(0),
        pinnedTabsManager: PinnedTabsManager = WindowControllersManager.shared.pinnedTabsManager
    ) {
        self.tabCollection = tabCollection
        self.pinnedTabsManager = pinnedTabsManager
        super.init()

        subscribeToTabs()
        applySelectionWhenPinnedTabsAreReady(selectionIndex)

        if tabCollection.tabs.isEmpty {
            appendNewTab(with: .homePage)
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
        guard changesEnabled || forceChange else { return false }
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return false
        }

        selectionIndex = .regular(index)
        selectParentOnRemoval = selectedTabViewModel === previouslySelectedTabViewModel && selectParentOnRemoval
        return true
    }

    @discardableResult func selectPinnedTab(at index: Int, forceChange: Bool = false) -> Bool {
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

    @discardableResult func select(at index: TabIndex, forceChange: Bool = false) -> Bool {
        switch index {
        case .regular(let i):
            return selectRegularTab(at: i, forceChange: forceChange)
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

        if selectRegularTab(at: index) {
            tabCollection.tabs[index].setContent(content)
            delegate?.tabCollectionViewModel(self, didSelectAt: index)
            return true
        }
        return false
    }

    func selectNext() {
        guard changesEnabled else { return }
        guard allTabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = nextIndex(from: selectionIndex)
            select(at: newSelectionIndex)
            if newSelectionIndex.isRegularTab {
                delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex.index)
            }
        } else {
            let newSelectionIndex = firstIndex()
            select(at: newSelectionIndex)
            if newSelectionIndex.isRegularTab {
                delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex.index)
            }
        }
    }

    func selectPrevious() {
        guard changesEnabled else { return }
        guard allTabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = previousIndex(from: selectionIndex)
            select(at: newSelectionIndex)
            if newSelectionIndex.isRegularTab {
                delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex.index)
            }
        } else {
            let newSelectionIndex = TabIndex.regular(tabCollection.tabs.count - 1)
            select(at: newSelectionIndex)
            delegate?.tabCollectionViewModel(self, didSelectAt: newSelectionIndex.index)
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
            selectRegularTab(at: tabCollection.tabs.count - 1, forceChange: forceChange)
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
        selectRegularTab(at: newSelectionIndex)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func insert(tab: Tab, at index: TabIndex = .regular(0), selected: Bool = true) {
        guard changesEnabled else { return }

        let tabCollection = tabCollection(for: index)
        tabCollection.insert(tab: tab, at: index.index)
        if selected {
            select(at: index)
        }
        if index.isRegularTab {
            delegate?.tabCollectionViewModelDidInsert(self, at: index.index, selected: selected)
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
        var newIndex = parentTabIndex.isPinnedTab ? 0 : parentTabIndex.index + 1
        while tabCollection.tabs[safe: newIndex]?.parentTab === parentTab { newIndex += 1 }
        insert(tab: tab, at: .regular(newIndex), selected: selected)
    }

    // MARK: - Removal

    func remove(at index: TabIndex, published: Bool = true) {
        switch index {
        case .regular(let i):
            return remove(at: i, published: published)
        case .pinned(let i):
            return removePinnedTab(at: i, published: published)
        }
    }

    func remove(at index: Int, published: Bool = true) {
        guard changesEnabled else { return }

        let parentTab = tabCollection.tabs[safe: index]?.parentTab
        guard tabCollection.remove(at: index, published: published) else { return }

        didRemoveTab(at: .regular(index), withParent: parentTab)
    }

    func removePinnedTab(at index: Int, published: Bool = true) {
        guard changesEnabled else { return }
        shouldBlockPinnedTabsManagerSubscriptions = true
        defer {
            shouldBlockPinnedTabsManagerSubscriptions = false
        }
        guard pinnedTabsManager.unpinTab(at: index, published: published) != nil else { return }

        didRemoveTab(at: .pinned(index), withParent: nil)
    }

    private func tabCollection(for selection: TabIndex) -> TabCollection {
        switch selection {
        case .regular:
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
            return .regular(index)
        }
        return nil
    }

    private func tab(at tabIndex: TabIndex) -> Tab? {
        switch tabIndex {
        case .pinned(let index):
            return pinnedTabsCollection.tabs[safe: index]
        case .regular(let index):
            return tabCollection.tabs[safe: index]
        }
    }

    private func didRemoveTab(at index: TabIndex, withParent parentTab: Tab?) {
        defer {
            if index.isRegularTab {
                let newSelectionIndex = self.selectionIndex?.isRegularTab == true ? self.selectionIndex?.index : nil
                delegate?.tabCollectionViewModel(self, didRemoveTabAt: index.index, andSelectTabAt: newSelectionIndex)
            }
        }

        guard index.isPinnedTab || tabCollection.tabs.count > 0 else {
            selectionIndex = nil
            return
        }

        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
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
                  let leftTab = tab(at: previousIndex(from: index)),
                  let rightTab = tab(at: index),
                  rightTab.parentTab !== parentTab && (leftTab.parentTab === parentTab || leftTab === parentTab) {
            // Select parent tab on left or another child tab on left instead of the tab on right
            newSelectionIndex = .regular(max(0, selectionIndex.index - 1))
        } else if selectionIndex > index {
            newSelectionIndex = previousIndex(from: selectionIndex)
        } else {
            newSelectionIndex = sanitizeIndex(selectionIndex)
        }

        select(at: newSelectionIndex)
    }

    func moveRegularTab(at fromIndex: Int, to otherViewModel: TabCollectionViewModel, at toIndex: Int) {
        guard changesEnabled else { return }

        let parentTab = tabCollection.tabs[safe: fromIndex]?.parentTab

        guard tabCollection.moveTab(at: fromIndex, to: otherViewModel.tabCollection, at: toIndex) else { return }

        didRemoveTab(at: .regular(fromIndex), withParent: parentTab)

        otherViewModel.selectRegularTab(at: toIndex)
        otherViewModel.delegate?.tabCollectionViewModelDidInsert(otherViewModel, at: toIndex, selected: true)
        otherViewModel.selectParentOnRemoval = true
    }

    func removeAllTabs(except exceptionIndex: Int? = nil) {
        guard changesEnabled else { return }

        tabCollection.removeAll(andAppend: exceptionIndex.map { tabCollection.tabs[$0] })

        if exceptionIndex != nil {
            selectRegularTab(at: 0)
        } else {
            selectionIndex = nil
        }
        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabs(after index: Int) {
        guard changesEnabled else { return }

        tabCollection.removeTabs(after: index)

        if let currentSelection = selectionIndex, currentSelection.isRegularTab, !tabCollection.tabs.indices.contains(currentSelection.index) {
            selectionIndex = .regular(tabCollection.tabs.count - 1)
        }

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeAllTabsAndAppendNew(forceChange: Bool = false) {
        guard changesEnabled || forceChange else { return }

        tabCollection.removeAll(andAppend: Tab(content: .homePage))
        selectRegularTab(at: 0, forceChange: forceChange)

        delegate?.tabCollectionViewModelDidMultipleChanges(self)
    }

    func removeTabsAndAppendNew(at indexSet: IndexSet, forceChange: Bool = false) {
        guard !indexSet.isEmpty, changesEnabled || forceChange else { return }
        guard let selectionIndex = selectionIndex?.index else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        tabCollection.removeTabs(at: indexSet)
        if tabCollection.tabs.isEmpty {
            tabCollection.append(tab: Tab(content: .homePage))
            selectRegularTab(at: 0, forceChange: forceChange)
        } else {
            let selectionDiff = indexSet.reduce(0) { result, index in
                if index < selectionIndex {
                    return result + 1
                } else {
                    return result
                }
            }

            selectRegularTab(at: max(min(selectionIndex - selectionDiff, tabCollection.tabs.count - 1), 0), forceChange: forceChange)
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

    func duplicateTab(at tabIndex: TabIndex) {
        guard changesEnabled else { return }

        guard let tab = tab(at: tabIndex) else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return
        }

        let tabCopy = Tab(content: tab.content, sessionStateData: tab.sessionStateData)
        let newIndex = tabIndex.next

        tabCollection(for: tabIndex).insert(tab: tabCopy, at: newIndex.index)
        select(at: newIndex)

        if newIndex.isRegularTab {
            delegate?.tabCollectionViewModelDidInsert(self, at: newIndex.index, selected: true)
        }
    }

    func pinTab(at index: Int) {
        guard changesEnabled else { return }

        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return
        }

        if tabCollection.tabs.count == 1 {
            appendNewTab(with: .homePage, selected: false)
        }

        let tab = tabCollection.tabs[index]

        pinnedTabsManager.pin(tab)
        remove(at: index, published: false)
        selectPinnedTab(at: pinnedTabsCollection.tabs.count - 1)
    }

    func unpinTab(at index: Int) {
        guard changesEnabled else { return }
        shouldBlockPinnedTabsManagerSubscriptions = true
        defer {
            shouldBlockPinnedTabsManagerSubscriptions = false
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

    // TODO
    func moveTab(at index: Int, to newIndex: Int) {
        guard changesEnabled else { return }

        tabCollection.moveTab(at: index, to: newIndex)
        selectRegularTab(at: newIndex)

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
        selectRegularTab(at: selectionIndex.index, forceChange: forceChange)
    }

    private func applySelectionWhenPinnedTabsAreReady(_ selection: TabIndex?) {
        pinnedTabsManager.didSetUpPinnedTabsPublisher
            .prefix(1)
            .sink { [weak self] in
                if self?.selectionIndex != selection {
                    self?.selectionIndex = selection
                }
                self?.subscribeToPinnedTabsManager()
            }
            .store(in: &cancellables)
    }

    private func subscribeToPinnedTabsManager() {
        pinnedTabsManager.didUnpinTabPublisher
            .filter { [weak self] _ in self?.shouldBlockPinnedTabsManagerSubscriptions == false }
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
            selectedTabViewModel = tabViewModel(at: selectionIndex.index)
        case pinnedTabsCollection:
            selectedTabViewModel = pinnedTabsManager.tabViewModel(at: selectionIndex.index)
        default:
            break
        }

        selectedTabViewModel?.tab.lastSelectedAt = Date()
        self.selectedTabViewModel = selectedTabViewModel
    }

    private func firstIndex() -> TabIndex {
        return pinnedTabsCollection.tabs.count > 0 ? .pinned(0) : .regular(0)
    }

    private func nextIndex(from current: TabIndex) -> TabIndex {
        switch current {
        case .pinned(let index):
            if index >= pinnedTabsCollection.tabs.count - 1 {
                return .regular(0)
            }
            return .pinned(index + 1)
        case .regular(let index):
            if index >= tabCollection.tabs.count - 1 {
                return firstIndex()
            }
            return .regular(index + 1)
        }
    }

    private func sanitizeIndex(_ idx: TabIndex) -> TabIndex {
        switch idx {
        case .pinned(let index):
            if index >= pinnedTabsCollection.tabs.count {
                return .regular(min(index - pinnedTabsCollection.tabs.count, tabCollection.tabs.count - 1))
            }
            return idx
        case .regular(let index):
            return .regular(max(0, min(index, tabCollection.tabs.count - 1)))
        }
    }

    private func previousIndex(from current: TabIndex) -> TabIndex {
        switch current {
        case .pinned(let index):
            if index == 0 {
                return .regular(tabCollection.tabs.count - 1)
            }
            return .pinned(index - 1)
        case .regular(let index):
            if index == 0 {
                let pinnedTabsCount = pinnedTabsCollection.tabs.count
                return pinnedTabsCount > 0 ? .pinned(pinnedTabsCount - 1) : .regular(tabCollection.tabs.count - 1)
            }
            return .regular(index - 1)
        }
    }
}
// swiftlint:enable type_body_length
