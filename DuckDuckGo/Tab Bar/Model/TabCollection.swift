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
import os.log

final class TabCollection: NSObject {

    @Published private(set) var tabs: [Tab]
    @Published private(set) var lastRemovedTabCache: (url: URL?, index: Int)?

    init(tabs: [Tab] = []) {
        self.tabs = tabs
    }

    deinit {
        tabs.forEach { $0.tabWillClose() }
    }

    func append(tab: Tab) {
        tabs.append(tab)
    }

    func insert(tab: Tab, at index: Int) {
        guard index >= 0, index <= tabs.endIndex else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        tabs.insert(tab, at: index)
    }

    func remove(at index: Int) -> Bool {
        guard index >= 0, index < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return false
        }

        saveLastRemovedTab(at: index)
        tabWillClose(at: index)
        tabs.remove(at: index)

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
        guard
            !indexSet.contains(where: { index in
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
        tabs[index].tabWillClose()
    }

    private func tabsWillClose(range: Range<Int>) {
        for i in range {
            keepLocalHistory(of: tabs[i])
            tabs[i].tabWillClose()
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

        var tabs = tabs
        tabs.insert(tabs.remove(at: index), at: newIndex)
        self.tabs = tabs
    }

    func replaceTab(at index: Int, with tab: Tab) {
        guard index >= 0, index < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        tabs[index].tabWillClose()
        keepLocalHistory(of: tabs[index])
        tabs[index] = tab
    }

    // MARK: - Last Removed Tab

    private func saveLastRemovedTab(at index: Int) {
        guard index >= 0, index < tabs.count else {
            os_log("TabCollection: Index out of bounds", type: .error)
            return
        }

        let tab = tabs[index]
        lastRemovedTabCache = (tab.content.url, index)
    }

    func putBackLastRemovedTab() {
        guard let lastRemovedTabCache = lastRemovedTabCache else {
            os_log("TabCollection: No tab removed yet", type: .error)
            return
        }

        let tab = Tab(content: lastRemovedTabCache.url.map(Tab.TabContent.url) ?? .homePage)
        insert(tab: tab, at: min(lastRemovedTabCache.index, tabs.count))
        self.lastRemovedTabCache = nil
    }

    func cleanLastRemovedTab() {
        lastRemovedTabCache = nil
    }

    // MARK: - Fire button

    // Visited domains of removed tabs used for fire button logic
    var localHistoryOfRemovedTabs = Set<String>()

    private func keepLocalHistory(of tab: Tab) {
        localHistoryOfRemovedTabs.formUnion(tab.localHistory)
    }

}
