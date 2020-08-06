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

class TabCollection {

    @Published private(set) var tabs: [Tab] = []

    init() {
        listenUrlEvents()
    }

    func append(tab: Tab) {
        tabs.append(tab)
    }

    func remove(at index: Int) {
        tabs.remove(at: index)
    }

    func moveItem(at index: Int, to newIndex: Int) {
        if index == newIndex {
            return
        }
        if abs(index - newIndex) == 1 {
            tabs.swapAt(index, newIndex)
            return
        }

        var tabs = self.tabs
        tabs.insert(tabs.remove(at: index), at: newIndex)
        self.tabs = tabs
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
