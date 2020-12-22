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

    func tabCollectionViewModelDidAppend(_ tabCollectionViewModel: TabCollectionViewModel)
    func tabCollectionViewModelDidAppendAndSelect(_ tabCollectionViewModel: TabCollectionViewModel)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didAppendAtMultipleAndSelectAt index: Int)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didInsertAndSelectAt index: Int)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveTabAt removalIndex: Int,
                                andSelectTabAt selectionIndex: Int?)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel,
                                didRemoveAllExcept exceptionIndex: Int?,
                                andSelectAt selectionIndex: Int?)
    func tabCollectionViewModelDidRemoveAllAndAppend(_ tabCollectionViewModel: TabCollectionViewModel)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didMoveTabAt index: Int, to newIndex: Int)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didSelectNextAt selectionIndex: Int?)
    func tabCollectionViewModel(_ tabCollectionViewModel: TabCollectionViewModel, didSelectPreviousAt selectionIndex: Int?)

}

class TabCollectionViewModel {

    weak var delegate: TabCollectionViewModelDelegate?

    private(set) var tabCollection: TabCollection
    
    private var tabViewModels = [Tab: TabViewModel]()
    @Published private(set) var selectionIndex: Int? {
        didSet {
            updateSelectedTabViewModel()
        }
    }
    @Published private(set) var selectedTabViewModel: TabViewModel?
    @Published private(set) var canInsertLastRemovedTab: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(tabCollection: TabCollection) {
        self.tabCollection = tabCollection

        subscribeToTabs()
        subscribeToLastRemovedTab()
        appendNewTab()
    }

    convenience init() {
        let tabCollection = TabCollection()
        self.init(tabCollection: tabCollection)
    }

    func tabViewModel(at index: Int) -> TabViewModel? {
        guard index >= 0, tabCollection.tabs.count > index else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return nil
        }

        let tab = tabCollection.tabs[index]
        return tabViewModels[tab]
    }

    @discardableResult func select(at index: Int) -> Bool {
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return false
        }

        selectionIndex = index
        return true
    }

    func selectNext() {
        guard tabCollection.tabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = (selectionIndex + 1) % tabCollection.tabs.count
            select(at: newSelectionIndex)
            delegate?.tabCollectionViewModel(self, didSelectNextAt: newSelectionIndex)
        } else {
            select(at: 0)
            delegate?.tabCollectionViewModel(self, didSelectNextAt: 0)
        }
    }

    func selectPrevious() {
        guard tabCollection.tabs.count > 0 else {
            os_log("TabCollectionViewModel: No tabs for selection", type: .error)
            return
        }

        if let selectionIndex = selectionIndex {
            let newSelectionIndex = selectionIndex - 1 >= 0 ? selectionIndex - 1 : tabCollection.tabs.count - 1
            select(at: newSelectionIndex)
            delegate?.tabCollectionViewModel(self, didSelectPreviousAt: newSelectionIndex)
        } else {
            select(at: tabCollection.tabs.count - 1)
            delegate?.tabCollectionViewModel(self, didSelectPreviousAt: tabCollection.tabs.count - 1)
        }
    }

    func appendNewTab() {
        tabCollection.append(tab: Tab())
        select(at: tabCollection.tabs.count - 1)

        delegate?.tabCollectionViewModelDidAppendAndSelect(self)
    }

    func appendNewTabAfterSelected(with webViewConfiguration: WebViewConfiguration? = nil) {
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }
        let tab: Tab
        if let webViewConfiguration = webViewConfiguration {
            tab = Tab(webViewConfiguration: webViewConfiguration)
        } else {
            tab = Tab()
        }

        let newIndex = selectionIndex + 1
        tabCollection.insert(tab: tab, at: newIndex)
        select(at: newIndex)

        delegate?.tabCollectionViewModel(self, didInsertAndSelectAt: newIndex)
    }

    func append(tab: Tab, selected: Bool = true) {
        guard let selectionIndex = self.selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }

        tabCollection.append(tab: tab)
        if selected {
            select(at: tabCollection.tabs.count - 1)
            delegate?.tabCollectionViewModelDidAppendAndSelect(self)
        } else {
            select(at: selectionIndex)
            delegate?.tabCollectionViewModelDidAppend(self)
        }
    }

    func append(tabs: [Tab]) {
        tabs.forEach {
            tabCollection.append(tab: $0)
        }
        let newSelectionIndex = tabCollection.tabs.count - 1
        select(at: newSelectionIndex)

        delegate?.tabCollectionViewModel(self, didAppendAtMultipleAndSelectAt: newSelectionIndex)
    }

    func insertNewTab(at index: Int = 0) {
        tabCollection.insert(tab: Tab(), at: index)
        select(at: index)

        delegate?.tabCollectionViewModel(self, didInsertAndSelectAt: index)
    }

    func remove(at index: Int) {
        guard tabCollection.remove(at: index) else { return }

        guard tabCollection.tabs.count > 0 else {
            selectionIndex = nil
            delegate?.tabCollectionViewModel(self, didRemoveTabAt: index, andSelectTabAt: nil)
            return
        }
        
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        let newSelectionIndex: Int
        if selectionIndex > index {
            newSelectionIndex = max(selectionIndex - 1, 0)
        } else {
            newSelectionIndex = max(min(selectionIndex, tabCollection.tabs.count - 1), 0)
        }
        select(at: newSelectionIndex)

        delegate?.tabCollectionViewModel(self, didRemoveTabAt: index, andSelectTabAt: newSelectionIndex)
    }

    func removeAllTabs(except exceptionIndex: Int? = nil) {
        if tabCollection.tabs.isEmpty { return }

        tabCollection.tabs.enumerated().reversed().forEach {
            if exceptionIndex != $0.offset {
                if !tabCollection.remove(at: $0.offset) {
                    os_log("TabCollectionViewModel: Failed to remove item", type: .error)
                }
            }
        }

        if exceptionIndex != nil {
            select(at: 0)
            delegate?.tabCollectionViewModel(self, didRemoveAllExcept: exceptionIndex, andSelectAt: 0)
        } else {
            selectionIndex = nil
            delegate?.tabCollectionViewModel(self, didRemoveAllExcept: exceptionIndex, andSelectAt: nil)
        }
    }

    func removeAllTabsAndAppendNewTab() {
        tabCollection.removeAllAndAppend(tab: Tab())
        select(at: 0)

        delegate?.tabCollectionViewModelDidRemoveAllAndAppend(self)
    }

    func remove(ownerOf webView: WebView) {
        let webViews = tabCollection.tabs.map { $0.webView }
        guard let index = webViews.firstIndex(of: webView) else {
            os_log("TabCollection: Failed to get index of the tab", type: .error)
            return
        }

        self.remove(at: index)
    }

    func removeSelected() {
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }

        self.remove(at: selectionIndex)
    }

    func insertLastRemovedTab() {
        let lastRemovedTabIndex = tabCollection.lastRemovedTabCache?.index
        tabCollection.insertLastRemovedTab()

        if let lastRemovedTabIndex = lastRemovedTabIndex {
            select(at: lastRemovedTabIndex)

            delegate?.tabCollectionViewModel(self, didInsertAndSelectAt: lastRemovedTabIndex)
        }
    }

    func duplicateTab(at index: Int) {
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            return
        }

        let tab = tabCollection.tabs[index]
        let tabCopy = Tab()
        tabCopy.url = tab.url
        let newIndex = index + 1

        tabCollection.insert(tab: tabCopy, at: newIndex)
        select(at: newIndex)

        delegate?.tabCollectionViewModel(self, didInsertAndSelectAt: newIndex)
    }

    func moveTab(at index: Int, to newIndex: Int) {
        tabCollection.moveTab(at: index, to: newIndex)
        select(at: newIndex)

        delegate?.tabCollectionViewModel(self, didMoveTabAt: index, to: newIndex)
    }

    private func subscribeToTabs() {
        tabCollection.$tabs.sink { [weak self] newTabs in
            self?.removeTabViewModelsIfNeeded(newTabs: newTabs)
            self?.addTabViewModelsIfNeeded(newTabs: newTabs)
        } .store(in: &cancellables)
    }

    private func subscribeToLastRemovedTab() {
        tabCollection.$lastRemovedTabCache.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateCanInsertLastRemovedTab()
        } .store(in: &cancellables)
    }

    private func removeTabViewModelsIfNeeded(newTabs: [Tab]) {
        tabViewModels = tabViewModels.filter { (item) -> Bool in
            newTabs.contains(item.key)
        }
    }

    private func addTabViewModelsIfNeeded(newTabs: [Tab]) {
        newTabs.forEach { (tab) in
            if tabViewModels[tab] == nil {
                tabViewModels[tab] = TabViewModel(tab: tab)
            }
        }
    }

    private func updateSelectedTabViewModel() {
        guard let selectionIndex = selectionIndex else {
            selectedTabViewModel = nil
            return
        }
        let selectedTabViewModel = tabViewModel(at: selectionIndex)
        self.selectedTabViewModel = selectedTabViewModel
    }

    private func updateCanInsertLastRemovedTab() {
        canInsertLastRemovedTab = tabCollection.lastRemovedTabCache != nil
    }

}
