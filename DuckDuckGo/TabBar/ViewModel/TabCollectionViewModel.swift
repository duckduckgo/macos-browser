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

    private var cancelables = Set<AnyCancellable>()

    init(tabCollection: TabCollection) {
        self.tabCollection = tabCollection

        bindTabs()
        appendNewTab()
    }

    convenience init() {
        let tabCollection = TabCollection()
        self.init(tabCollection: tabCollection)
    }

    func tabViewModel(at index: Int) -> TabViewModel? {
        guard index >= 0, tabCollection.tabs.count > index else {
            os_log("TabCollectionViewModel: Index out of bounds", log: OSLog.Category.general, type: .error)
            return nil
        }

        let tab = tabCollection.tabs[index]
        return tabViewModels[tab]
    }

    func select(at index: Int) {
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", log: OSLog.Category.general, type: .error)
            selectionIndex = nil
            return
        }

        selectionIndex = index
    }

    func appendNewTab() {
        tabCollection.append(tab: Tab())
        select(at: tabCollection.tabs.count - 1)
    }

    func appendNewTabAfterSelected() {
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollectionViewModel: No tab selected", log: OSLog.Category.general, type: .error)
            return
        }
        tabCollection.insert(tab: Tab(), at: selectionIndex + 1)
        select(at: selectionIndex + 1)
    }

    func remove(at index: Int) {
        guard tabCollection.remove(at: index) else { return }

        guard tabCollection.tabs.count > 0 else { return }
        guard let selectionIndex = selectionIndex else {
            os_log("TabCollection: No tab selected", log: OSLog.Category.general, type: .error)
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
            os_log("TabCollectionViewModel: No tab selected", log: OSLog.Category.general, type: .error)
            return
        }

        remove(at: selectionIndex)
    }

    func removeOtherTabs(except index: Int) {
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", log: OSLog.Category.general, type: .error)
            return
        }
        let tab = tabCollection.tabs[index]

        var index = tabCollection.tabs.count - 1
        tabCollection.tabs.reversed().forEach {
            if tab != $0 {
                if !tabCollection.remove(at: index) {
                    os_log("TabCollectionViewModel: Failed to remove item", log: OSLog.Category.general, type: .error)
                }
            }
            index -= 1
        }
        select(at: 0)
    }

    func duplicateTab(at index: Int) {
        guard index >= 0, index < tabCollection.tabs.count else {
            os_log("TabCollectionViewModel: Index out of bounds", log: OSLog.Category.general, type: .error)
            return
        }

        let tab = tabCollection.tabs[index]
        let tabCopy = Tab()
        tabCopy.url = tab.url
        let newIndex = index + 1

        tabCollection.insert(tab: tabCopy, at: newIndex)
        select(at: newIndex)
    }

    private func bindTabs() {
        tabCollection.$tabs.sink { newTabs in
            self.removeTabViewModelsIfNeeded(newTabs: newTabs)
            self.addTabViewModelsIfNeeded(newTabs: newTabs)
        } .store(in: &cancelables)
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

}
