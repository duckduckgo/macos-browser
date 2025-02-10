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
import History

final class TabCollection: NSObject {

    @Published private(set) var tabs: [Tab]

    let didRemoveTabPublisher = PassthroughSubject<(Tab, Int), Never>()

    init(tabs: [Tab] = []) {
        self.tabs = tabs
    }

    func append(tab: Tab) {
        tabs.append(tab)

#if !APPSTORE
        if #available(macOS 14.4, *) {
            WebExtensionManager.shared.eventsListener.didOpenTab(tab)
        }
#endif
    }

    @discardableResult
    func insert(_ tab: Tab, at index: Int) -> Bool {
        guard index >= 0, index <= tabs.endIndex else {
            assertionFailure("TabCollection: Index out of bounds")
            return false
        }

        tabs.insert(tab, at: index)
#if !APPSTORE
        if #available(macOS 14.4, *) {
            WebExtensionManager.shared.eventsListener.didOpenTab(tab)
        }
#endif
        return true
    }

    func removeTab(at index: Int, published: Bool = true, forced: Bool = false) -> Bool {
        guard tabs.indices.contains(index) else {
            assertionFailure("TabCollection: Index out of bounds")
            return false
        }

        let tab = tabs[index]
        tabWillClose(at: index, forced: forced)

        tabs.remove(at: index)
        if published {
            didRemoveTabPublisher.send((tab, index))
        }

        return true
    }

    func moveTab(at fromIndex: Int, to otherCollection: TabCollection, at toIndex: Int) -> Bool {
        guard let tab = tabs[safe: fromIndex],
              otherCollection.insert(tab, at: toIndex)
        else {
            assertionFailure("TabCollection: Index out of bounds")
            return false
        }

        tabs.remove(at: fromIndex)
        return true
    }

    func removeAll(andAppend tab: Tab? = nil) {
        tabsWillClose(range: 0..<tabs.count)
        tabs = tab.map { [$0] } ?? []
    }

    func removeTabs(before index: Int) {
        tabsWillClose(range: 0..<index)
        tabs.removeSubrange(0..<index)
    }

    func removeTabs(after index: Int) {
        tabsWillClose(range: (index + 1)..<tabs.count)
        tabs.removeSubrange((index + 1)...)
    }

    func removeTabs(at indexSet: IndexSet) {
        guard !indexSet.contains(where: { index in
            index < 0 && index >= tabs.count
        }) else {
            assertionFailure("TabCollection: Index out of bounds")
            return
        }

        for i in indexSet {
            tabWillClose(at: i, forced: false)
        }
        tabs.remove(atOffsets: indexSet)
    }

    func reorderTabs(_ newOrder: [Tab]) {
        assert(tabs.count == newOrder.count && Set(tabs) == Set(newOrder), "tabs changed when reordering")
        tabs = newOrder
    }

    private func tabWillClose(at index: Int, forced: Bool) {
        if !forced {
            keepLocalHistory(of: tabs[index])
        }

#if !APPSTORE
        if #available(macOS 14.4, *) {
            WebExtensionManager.shared.eventsListener.didCloseTab(tabs[index], windowIsClosing: false)
        }
#endif
    }

    private func tabsWillClose(range: Range<Int>) {
        for i in range {
            keepLocalHistory(of: tabs[i])

#if !APPSTORE
            if #available(macOS 14.4, *) {
                WebExtensionManager.shared.eventsListener.didCloseTab(tabs[i], windowIsClosing: false)
            }
#endif
        }
    }

    func moveTab(at index: Int, to newIndex: Int) {
        guard tabs.indices.contains(index), tabs.indices.contains(newIndex) else {
            assertionFailure("TabCollection: Index out of bounds")
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
        guard tabs.indices.contains(index) else {
            assertionFailure("TabCollection: Index out of bounds")
            return
        }

        keepLocalHistory(of: tabs[index])
        let oldTab = tabs[index]
        tabs[index] = tab

#if !APPSTORE
        if #available(macOS 14.4, *) {
            WebExtensionManager.shared.eventsListener.didReplaceTab(oldTab, with: tab)
        }
#endif
    }

    // MARK: - Fire button

    // Visits of removed tabs used for fire button logic
    var localHistoryOfRemovedTabs = [Visit]()

    private func keepLocalHistory(of tab: Tab) {
        for visit in tab.localHistory where !localHistoryOfRemovedTabs.contains(visit) {
            localHistoryOfRemovedTabs.append(visit)
        }
    }

}
