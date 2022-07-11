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

import Foundation
import Combine
import os

protocol PinnedTabsManager {
    var didUnpinTabPublisher: AnyPublisher<Int, Never> { get }

    var tabCollection: TabCollection { get }
    var tabViewModels: [Tab: TabViewModel] { get }

    var pinnedDomains: Set<String> { get }
    func isDomainPinned(_ domain: String) -> Bool

    func isTabPinned(_ tab: Tab) -> Bool

    func pin(_ tab: Tab)
    func pin(_ tab: Tab, at index: Int?)
    func unpin(_ tab: Tab, published: Bool) -> Bool
    func unpinTab(at index: Int, published: Bool) -> Tab?
    func tabViewModel(at index: Int) -> TabViewModel?

    func setUp(with collection: TabCollection)
}

extension PinnedTabsManager {
    func isDomainPinned(_ domain: String) -> Bool {
        pinnedDomains.contains(domain)
    }

    var pinnedDomains: Set<String> {
        Set(tabCollection.tabs.compactMap { $0.url?.host?.dropWWW() })
    }
}

final class LocalPinnedTabsManager: PinnedTabsManager, ObservableObject {

    private(set) var tabCollection: TabCollection
    private(set) var tabViewModels = [Tab: TabViewModel]()

    let didUnpinTabPublisher: AnyPublisher<Int, Never>

    func setUp(with collection: TabCollection) {
        tabCollection.removeAll()
        for tab in collection.tabs {
            tabCollection.append(tab: tab)
        }
    }

    func isTabPinned(_ tab: Tab) -> Bool {
        tabCollection.tabs.contains(tab)
    }

    func pin(_ tab: Tab) {
        pin(tab, at: nil)
    }

    func pin(_ tab: Tab, at index: Int?) {
        if let index = index {
            tabCollection.insert(tab: tab, at: index)
        } else {
            tabCollection.append(tab: tab)
        }
    }

    func unpin(_ tab: Tab, published: Bool = false) -> Bool {
        guard let index = tabCollection.tabs.firstIndex(of: tab) else {
            os_log("PinnedTabsManager: unable to unpin a tab")
            return false
        }
        guard tabCollection.remove(at: index, published: published) else {
            os_log("PinnedTabsManager: unable to unpin a tab")
            return false
        }
        didUnpinTabSubject.send(index)
        return true
    }

    func unpinTab(at index: Int, published: Bool = false) -> Tab? {
        guard let tab = tabCollection.tabs[safe: index] else {
            os_log("PinnedTabsManager: unable to unpin a tab")
            return nil
        }
        guard unpin(tab, published: published) else {
            os_log("PinnedTabsManager: unable to unpin a tab")
            return nil
        }
        return tab
    }

    func tabViewModel(at index: Int) -> TabViewModel? {
        guard index >= 0, tabCollection.tabs.count > index else {
            os_log("LocalPinnedTabsManager: Index out of bounds", type: .error)
            return nil
        }

        let tab = tabCollection.tabs[index]
        return tabViewModels[tab]
    }

    init(tabCollection: TabCollection = .init()) {
        didUnpinTabPublisher = didUnpinTabSubject.eraseToAnyPublisher()
        self.tabCollection = tabCollection
        subscribeToPinnedTabs()
    }

    // MARK: - Private

    private let didUnpinTabSubject = PassthroughSubject<Int, Never>()
    private var cancellables: Set<AnyCancellable> = []

    private func subscribeToPinnedTabs() {
        tabCollection.$tabs.sink { [weak self] newTabs in
            guard let self = self else { return }

            let new = Set(newTabs)
            let old = Set(self.tabViewModels.keys)

            self.removeTabViewModels(old.subtracting(new))
            self.addTabViewModels(new.subtracting(old))
        } .store(in: &cancellables)
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
