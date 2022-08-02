//
//  PinnedTabsViewModel.swift
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

final class PinnedTabsViewModel: ObservableObject {

    @Published var items: [Tab] = [] {
        didSet {
            if oldValue != items && Set(oldValue) == Set(items) {
                tabsDidReorderSubject.send(items)
                if let selectedItem = selectedItem {
                    selectedItemIndex = items.firstIndex(of: selectedItem)
                }
            }
        }
    }

    @Published var selectedItem: Tab? {
        didSet {
            if let selectedItem = selectedItem {
                selectedItemIndex = items.firstIndex(of: selectedItem)
            } else {
                selectedItemIndex = nil
            }
            updateItemsWithoutSeparator()
        }
    }

    @Published var hoveredItem: Tab? {
        didSet {
            if let hoveredItem = hoveredItem {
                hoveredItemIndex = items.firstIndex(of: hoveredItem)
            } else {
                hoveredItemIndex = nil
            }
        }
    }

    @Published var shouldDrawLastItemSeparator: Bool = true {
        didSet {
            updateItemsWithoutSeparator()
        }
    }

    @Published private(set) var selectedItemIndex: Int?
    @Published private(set) var hoveredItemIndex: Int?
    @Published private(set) var dragMovesWindow: Bool = true

    @Published private(set) var itemsWithoutSeparator: Set<Tab> = []

    let contextMenuActionPublisher: AnyPublisher<ContextMenuAction, Never>
    let tabsDidReorderPublisher: AnyPublisher<[Tab], Never>

    // MARK: -

    init(collection: TabCollection, fireproofDomains: FireproofDomains = .shared) {
        tabsDidReorderPublisher = tabsDidReorderSubject.eraseToAnyPublisher()
        contextMenuActionPublisher = contextMenuActionSubject.eraseToAnyPublisher()
        self.fireproofDomains = fireproofDomains
        tabsCancellable = collection.$tabs.assign(to: \.items, onWeaklyHeld: self)

        dragMovesWindowCancellable = $items
            .combineLatest($selectedItem) { (tabs, selectedTab) -> Bool in
                tabs.count == 1 && selectedTab != nil
            }
            .removeDuplicates()
            .assign(to: \.dragMovesWindow, onWeaklyHeld: self)
    }

    private let tabsDidReorderSubject = PassthroughSubject<[Tab], Never>()
    private let contextMenuActionSubject = PassthroughSubject<ContextMenuAction, Never>()
    private var tabsCancellable: AnyCancellable?
    private var dragMovesWindowCancellable: AnyCancellable?
    private var fireproofDomains: FireproofDomains

    private func updateItemsWithoutSeparator() {
        var items = Set<Tab>()
        if let selectedItem = selectedItem {
            items.insert(selectedItem)
        }
        if let selectedItemIndex = selectedItemIndex, selectedItemIndex > 0 {
            items.insert(self.items[selectedItemIndex - 1])
        }
        if !shouldDrawLastItemSeparator, let lastItem = self.items.last {
            items.insert(lastItem)
        }
        itemsWithoutSeparator = items
    }
}

// MARK: - Context Menu

extension PinnedTabsViewModel {

    enum ContextMenuAction {
        case unpin(Int)
        case duplicate(Int)
        case bookmark(Tab)
        case fireproof(Tab)
        case removeFireproofing(Tab)
        case close(Int)
    }

    func isFireproof(_ tab: Tab) -> Bool {
        guard let host = tab.url?.host else {
            os_log("PinnedTabsViewModel: Failed to get url of a tab", type: .error)
            return false
        }
        return fireproofDomains.isFireproof(fireproofDomain: host)
    }

    func unpin(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            os_log("PinnedTabsViewModel: Failed to get index of a tab", type: .error)
            return
        }
        contextMenuActionSubject.send(.unpin(index))
    }

    func duplicate(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            os_log("PinnedTabsViewModel: Failed to get index of a tab", type: .error)
            return
        }
        contextMenuActionSubject.send(.duplicate(index))
    }

    func close(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            os_log("PinnedTabsViewModel: Failed to get index of a tab", type: .error)
            return
        }
        contextMenuActionSubject.send(.close(index))
    }

    func bookmark(_ tab: Tab) {
        contextMenuActionSubject.send(.bookmark(tab))
    }

    func fireproof(_ tab: Tab) {
        contextMenuActionSubject.send(.fireproof(tab))
    }

    func removeFireproofing(_ tab: Tab) {
        contextMenuActionSubject.send(.removeFireproofing(tab))
    }
}
