//
//  PinnedTabsManager.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import AppKit
import Combine
import Common
import Foundation
import os.log

final class PinnedTabsManager {

    private(set) var tabCollection: TabCollection
    private(set) var tabViewModels = [Tab: TabViewModel]()

    let didUnpinTabPublisher: AnyPublisher<Int, Never>

    func pin(_ tab: Tab, at index: Int? = nil) {
        if let index = index {
            tabCollection.insert(tab, at: index)
        } else {
            tabCollection.append(tab: tab)
        }

#if !APPSTORE
        if #available(macOS 14.4, *) {
            WebExtensionManager.shared.eventsListener.didChangeTabProperties([.pinned], for: tab)
        }
#endif
    }

    func unpinTab(at index: Int, published: Bool = false) -> Tab? {
        guard let tab = tabCollection.tabs[safe: index] else {
            Logger.general.debug("PinnedTabsManager: unable to unpin a tab")
            return nil
        }
        guard tabCollection.removeTab(at: index, published: published) else {
            Logger.general.debug("PinnedTabsManager: unable to unpin a tab")
            return nil
        }
        didUnpinTabSubject.send(index)

#if !APPSTORE
        if #available(macOS 14.4, *) {
            WebExtensionManager.shared.eventsListener.didChangeTabProperties([.pinned], for: tab)
        }
#endif
        return tab
    }

    func isTabPinned(_ tab: Tab) -> Bool {
        tabCollection.tabs.contains(tab)
    }

    func tabViewModel(at index: Int) -> TabViewModel? {
        guard index >= 0, tabCollection.tabs.count > index else {
            Logger.general.error("PinnedTabsManager: Index out of bounds")
            return nil
        }

        let tab = tabCollection.tabs[index]
        return tabViewModels[tab]
    }

    func isDomainPinned(_ domain: String) -> Bool {
        pinnedDomains.contains(domain)
    }

    var pinnedDomains: Set<String> {
        Set(tabCollection.tabs.compactMap { $0.url?.host })
    }

    func setUp(with collection: TabCollection) {
        tabCollection.removeAll()
        for tab in collection.tabs {
            tabCollection.append(tab: tab)
        }
    }

    init(tabCollection: TabCollection = .init()) {
        didUnpinTabPublisher = didUnpinTabSubject.eraseToAnyPublisher()
        self.tabCollection = tabCollection
        subscribeToPinnedTabs()
        subscribeToWindowWillClose()
    }

    private func subscribeToWindowWillClose() {
        windowWillCloseCancellable = NotificationCenter.default
            .publisher(for: NSWindow.willCloseNotification)
            .filter { $0.object is MainWindow }
            .asVoid()
            .sink { [weak self] in
                if NSApp.windows.filter({ $0 is MainWindow }).count == 1 {
                    self?.tabCollection.tabs.forEach { $0.stopAllMediaAndLoading() }
                }
            }
    }

    // MARK: - Private

    private let didUnpinTabSubject = PassthroughSubject<Int, Never>()
    private var tabsCancellable: AnyCancellable?
    private var windowWillCloseCancellable: AnyCancellable?

    private func subscribeToPinnedTabs() {
        tabsCancellable = tabCollection.$tabs.sink { [weak self] newTabs in
            guard let self = self else { return }

            let new = Set(newTabs)
            let old = Set(self.tabViewModels.keys)

            self.removeTabViewModels(old.subtracting(new))
            self.addTabViewModels(new.subtracting(old))
        }
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
}
