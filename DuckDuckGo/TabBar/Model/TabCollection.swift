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

protocol TabCollectionDelegate: AnyObject {

    func tabCollection(_ tabCollection: TabCollection, didAppend tab: Tab)
    func tabCollection(_ tabCollection: TabCollection, didInsert tab: Tab, at index: Int)
    func tabCollection(_ tabCollection: TabCollection, didRemoveTabAt index: Int)
    func tabCollection(_ tabCollection: TabCollection, didMoveTabAt index: Int, to newIndex: Int)

}

class TabCollection {

    @Published private(set) var tabs: [Tab] = []
    weak var delegate: TabCollectionDelegate?

    init() {
        listenUrlEvents()
    }

    func append(tab: Tab) {
        tabs.append(tab)
        delegate?.tabCollection(self, didAppend: tab)
    }

    func insert(tab: Tab, at index: Int) {
        guard index >= 0, index <= tabs.endIndex else {
            os_log("TabCollection: Index out of bounds", log: OSLog.Category.general, type: .error)
            return
        }

        tabs.insert(tab, at: index)
        delegate?.tabCollection(self, didInsert: tab, at: index)
    }

    func remove(at index: Int) -> Bool {
        guard index >= 0, index < tabs.count else {
            os_log("TabCollection: Index out of bounds", log: OSLog.Category.general, type: .error)
            return false
        }

        tabs.remove(at: index)
        delegate?.tabCollection(self, didRemoveTabAt: index)

        return true
    }

    func moveTab(at index: Int, to newIndex: Int) {
        guard index >= 0, index < tabs.count, newIndex >= 0, newIndex < tabs.count else {
            os_log("TabCollection: Index out of bounds", log: OSLog.Category.general, type: .error)
            return
        }

        if index == newIndex { return }
        if abs(index - newIndex) == 1 {
            tabs.swapAt(index, newIndex)
            delegate?.tabCollection(self, didMoveTabAt: index, to: newIndex)
            return
        }

        var tabs = self.tabs
        tabs.insert(tabs.remove(at: index), at: newIndex)
        self.tabs = tabs
        delegate?.tabCollection(self, didMoveTabAt: index, to: newIndex)
    }

}

// MARK: - URL Event

extension TabCollection {

    private func listenUrlEvents() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleUrlEvent(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleUrlEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding,
              let url = URL(string: path) else {
            os_log("TabCollection: URL initialization failed", log: OSLog.Category.general, type: .error)
            return
        }

        let newTab = Tab()
        newTab.url = url
        append(tab: newTab)
    }

}
