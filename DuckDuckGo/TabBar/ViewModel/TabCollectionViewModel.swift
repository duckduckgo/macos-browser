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

class TabCollectionViewModel {

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

    func select(at index: Int) {
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return
        }

        selectionIndex = index
    }

    func appendNewTab() {
        tabCollection.append(tab: Tab())
        select(at: tabCollection.tabs.count - 1)
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
        tabCollection.insert(tab: tab, at: selectionIndex + 1)
        select(at: selectionIndex + 1)
    }

    func append(tab: Tab) {
        tabCollection.append(tab: tab)
        select(at: tabCollection.tabs.count - 1)
    }

    func appendWithoutSelection(tab: Tab) {
        guard let selectionIndex = self.selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }
        tabCollection.append(tab: tab)
        select(at: selectionIndex)
    }

    func append(tabs: [Tab]) {
        tabs.forEach {
            tabCollection.append(tab: $0)
        }
        select(at: tabCollection.tabs.count - 1)
    }

    func insertNewTab(at index: Int = 0) {
        tabCollection.insert(tab: Tab(), at: index)
        select(at: index)
    }

    func remove(at index: Int) {
        guard tabCollection.remove(at: index) else { return }

        guard tabCollection.tabs.count > 0 else {
            selectionIndex = nil
            return
        }
        
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", type: .error)
            return
        }

        if selectionIndex > index {
            select(at: max(selectionIndex - 1, 0))
        } else {
            select(at: max(min(selectionIndex, tabCollection.tabs.count - 1), 0))
        }
    }

    func removeSelected() {
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", type: .error)
            return
        }

        remove(at: selectionIndex)
    }

    func removeAllTabs(except exceptionIndex: Int? = nil) {
        tabCollection.tabs.enumerated().reversed().forEach {
            if exceptionIndex != $0.offset {
                if !tabCollection.remove(at: $0.offset) {
                    os_log("TabCollectionViewModel: Failed to remove item", type: .error)
                }
            }
        }

        if exceptionIndex != nil {
            select(at: 0)
        } else {
            selectionIndex = nil
        }
    }

    func removeAllTabsAndAppendNewTab() {
        tabCollection.removeAllAndAppend(tab: Tab())
        select(at: 0)
    }

    func insertLastRemovedTab() {
        let lastRemovedTabIndex = tabCollection.lastRemovedTabCache?.index
        tabCollection.insertLastRemovedTab()

        if let lastRemovedTabIndex = lastRemovedTabIndex {
            select(at: lastRemovedTabIndex)
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
