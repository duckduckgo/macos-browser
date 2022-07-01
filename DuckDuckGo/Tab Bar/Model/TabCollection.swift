//
//  TabCollection.swift
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
import Combine
import os.log

final class TabCollection: NSObject {

    @Published private(set) var tabs: [Tab]

    let didRemoveTabPublisher = PassthroughSubject<(Tab, Int), Never>()

    init(tabs: [Tab] = []) {
        self.tabs = tabs
    }

    func append(tab: Tab) {
        tabs.append(tab)
    }

    @discardableResult
    func insert(tab: Tab, at index: Int) -> Bool {
        guard index >= 0, index <= tabs.endIndex else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return false
        }

        tabs.insert(tab, at: index)
        return true
    }

    func remove(at index: Int, published: Bool = true) -> Bool {
        guard tabs.indices.contains(index) else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return false
        }

        let tab = tabs[index]
        tabWillClose(at: index)
        tabs.remove(at: index)
        if published {
            didRemoveTabPublisher.send((tab, index))
        }

        return true
    }

    func moveTab(at fromIndex: Int, to otherCollection: TabCollection, at toIndex: Int) -> Bool {
        guard let tab = tabs[safe: fromIndex],
              otherCollection.insert(tab: tab, at: toIndex)
        else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return false
        }

        tabs.remove(at: fromIndex)
        return true
    }

    func removeAll(andAppend tab: Tab? = nil) {
        tabsWillClose(range: 0..<tabs.count)
        tabs = tab.map { [$0] } ?? []
    }

    func removeTabs(after index: Int) {
        tabsWillClose(range: (index + 1)..<tabs.count)
        tabs.removeSubrange((index + 1)...)
    }

    func removeTabs(at indexSet: IndexSet) {
        guard !indexSet.contains(where: { index in
            index < 0 && index >= tabs.count
        }) else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        for i in indexSet {
            tabWillClose(at: i)
        }
        tabs.remove(atOffsets: indexSet)
    }

    private func tabWillClose(at index: Int) {
        keepLocalHistory(of: tabs[index])
    }

    private func tabsWillClose(range: Range<Int>) {
        for i in range {
            keepLocalHistory(of: tabs[i])
        }
    }

    func moveTab(at index: Int, to newIndex: Int) {
        guard index >= 0, index < tabs.count, newIndex >= 0, newIndex < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        if index == newIndex { return }
        if abs(index - newIndex) == 1 {
            tabs.swapAt(index, newIndex)
            return
        }

        var tabs = self.tabs
        tabs.insert(tabs.remove(at: index), at: newIndex)
        self.tabs = tabs
    }

    func replaceTab(at index: Int, with tab: Tab) {
        guard index >= 0, index < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        keepLocalHistory(of: tabs[index])
        tabs[index] = tab
    }

    // MARK: - Fire button

    // Visited domains of removed tabs used for fire button logic
    var localHistoryOfRemovedTabs = Set<String>()

    private func keepLocalHistory(of tab: Tab) {
        localHistoryOfRemovedTabs.formUnion(tab.localHistory)
    }

}
