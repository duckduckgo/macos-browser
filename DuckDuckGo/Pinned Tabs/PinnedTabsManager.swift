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
    var didSetUpPinnedTabsPublisher: AnyPublisher<Void, Never> { get }
    var tabCollection: TabCollection { get set }
    var tabViewModels: [Tab: TabViewModel] { get }

    func isTabPinned(_ tab: Tab) -> Bool

    func pin(_ tab: Tab)
    func pin(_ tab: Tab, at index: Int?)
    func unpin(_ tab: Tab) -> Bool
    func unpinTab(at index: Int) -> Tab?
    func tabViewModel(at index: Int) -> TabViewModel?

    func setUp(with collection: TabCollection)
}

final class LocalPinnedTabsManager: PinnedTabsManager, ObservableObject {

    var tabCollection: TabCollection {
        didSet {
            subscribeToPinnedTabs()
        }
    }

    private(set) var tabViewModels = [Tab: TabViewModel]()

    let didSetUpPinnedTabsPublisher: AnyPublisher<Void, Never>

    func setUp(with collection: TabCollection) {
        tabCollection = collection
        didSetUpPinnedTabsSubject.send()
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

    func unpin(_ tab: Tab) -> Bool {
        guard let index = tabCollection.tabs.firstIndex(of: tab) else {
            return false
        }
        return tabCollection.remove(at: index, published: false)
    }

    func unpinTab(at index: Int) -> Tab? {
        guard let tab = tabCollection.tabs[safe: index], tabCollection.remove(at: index, published: false) else {
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
        didSetUpPinnedTabsPublisher = didSetUpPinnedTabsSubject.eraseToAnyPublisher()
        self.tabCollection = tabCollection
    }

    // MARK: - Private

    private let didSetUpPinnedTabsSubject = PassthroughSubject<Void, Never>()
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
