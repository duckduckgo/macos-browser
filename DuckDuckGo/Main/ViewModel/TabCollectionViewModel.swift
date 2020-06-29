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
    private(set) var tabViewModels = [Tab: TabViewModel]()

    private var cancelables = Set<AnyCancellable>()

    init(tabCollection: TabCollection) {
        self.tabCollection = tabCollection

        bindTabs()
    }

    convenience init() {
        let tabCollection = TabCollection()
        self.init(tabCollection: tabCollection)
    }

    private func bindTabs() {
        tabCollection.$tabs.sinkAsync { _ in self.removeViewModelsIfNeeded() } .store(in: &cancelables)
    }

    private func removeViewModelsIfNeeded() {
        tabViewModels = tabViewModels.filter { (item) -> Bool in
            tabCollection.tabs.contains(item.key)
        }
    }

    var selectedTabViewModel: TabViewModel? {
        guard let selectionIndex = tabCollection.selectionIndex else {
            return nil
        }
        return tabViewModel(at: selectionIndex)
    }

    func tabViewModel(at index: Int) -> TabViewModel? {
        guard tabCollection.tabs.count > index else {
            os_log("Index %lu higher than number of tabs %lu", log: OSLog.Category.general, type: .error, index, tabCollection.tabs.count)
            return nil
        }

        let tab = tabCollection.tabs[index]
        if tabViewModels[tab] == nil {
            tabViewModels[tab] = TabViewModel(tab: tab)
        }

        return tabViewModels[tab]
    }

}
