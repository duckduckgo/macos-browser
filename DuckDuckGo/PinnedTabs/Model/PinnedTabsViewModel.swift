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
import Common
import os.log

final class PinnedTabsViewModel: ObservableObject {

    @Published var items: [Tab] = [] {
        didSet {
            if oldValue != items {
                if let selectedItem = selectedItem, !items.contains(selectedItem) {
                    self.selectedItem = nil
                }
                if let hoveredItem = hoveredItem, !items.contains(hoveredItem) {
                    self.hoveredItem = nil
                }

                if Set(oldValue) == Set(items) {
                    tabsDidReorderSubject.send(items)
                    if let selectedItem = selectedItem {
                        selectedItemIndex = items.firstIndex(of: selectedItem)
                    }
                }
            }
        }
    }

    @Published var selectedItem: Tab? {
        didSet {
            if let selectedItem = selectedItem {
                selectedItemIndex = items.firstIndex(of: selectedItem)
                updateTabAudioState(tab: selectedItem)
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
                updateTabAudioState(tab: hoveredItem)
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
    @Published private(set) var audioStateView: AudioStateView = .notSupported

    @Published private(set) var itemsWithoutSeparator: Set<Tab> = []

    let contextMenuActionPublisher: AnyPublisher<ContextMenuAction, Never>
    let tabsDidReorderPublisher: AnyPublisher<[Tab], Never>

    // MARK: -

    init(
        collection: TabCollection,
        fireproofDomains: FireproofDomains = .shared,
        bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    ) {
        tabsDidReorderPublisher = tabsDidReorderSubject.eraseToAnyPublisher()
        contextMenuActionPublisher = contextMenuActionSubject.eraseToAnyPublisher()
        self.fireproofDomains = fireproofDomains
        self.bookmarkManager = bookmarkManager
        tabsCancellable = collection.$tabs.assign(to: \.items, onWeaklyHeld: self)

        dragMovesWindowCancellable = $items
            .map { $0.count == 1 }
            .removeDuplicates()
            .assign(to: \.dragMovesWindow, onWeaklyHeld: self)
    }

    private let tabsDidReorderSubject = PassthroughSubject<[Tab], Never>()
    private let contextMenuActionSubject = PassthroughSubject<ContextMenuAction, Never>()
    private var tabsCancellable: AnyCancellable?
    private var dragMovesWindowCancellable: AnyCancellable?
    private var fireproofDomains: FireproofDomains
    private var bookmarkManager: BookmarkManager

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

    private func updateTabAudioState(tab: Tab) {
        let audioState = tab.webView.audioState
        switch audioState {
        case .muted:
            audioStateView = .muted
        case .unmuted:
            audioStateView = .unmuted
        }
    }
}

// MARK: - Context Menu

extension PinnedTabsViewModel {

    enum ContextMenuAction {
        case unpin(Int)
        case duplicate(Int)
        case bookmark(Tab)
        case removeBookmark(Tab)
        case fireproof(Tab)
        case removeFireproofing(Tab)
        case close(Int)
        case muteOrUnmute(Tab)
    }

    enum AudioStateView {
        case muted
        case unmuted
        case notSupported
    }

    func isFireproof(_ tab: Tab) -> Bool {
        guard let host = tab.url?.host else {
            return false
        }
        return fireproofDomains.isFireproof(fireproofDomain: host)
    }

    func unpin(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            Logger.bitWarden.error("PinnedTabsViewModel: Failed to get index of a tab")
            return
        }
        contextMenuActionSubject.send(.unpin(index))
    }

    func duplicate(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            Logger.bitWarden.error("PinnedTabsViewModel: Failed to get index of a tab")
            return
        }
        contextMenuActionSubject.send(.duplicate(index))
    }

    func close(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            Logger.bitWarden.error("PinnedTabsViewModel: Failed to get index of a tab")
            return
        }
        contextMenuActionSubject.send(.close(index))
    }

    func isPinnedTabBookmarked(_ tab: Tab) -> Bool {
        guard let url = tab.url else { return false }
        return bookmarkManager.isUrlBookmarked(url: url)
    }

    func bookmark(_ tab: Tab) {
        contextMenuActionSubject.send(.bookmark(tab))
    }

    func removeBookmark(_ tab: Tab) {
        contextMenuActionSubject.send(.removeBookmark(tab))
    }

    func fireproof(_ tab: Tab) {
        contextMenuActionSubject.send(.fireproof(tab))
    }

    func removeFireproofing(_ tab: Tab) {
        contextMenuActionSubject.send(.removeFireproofing(tab))
    }

    func muteOrUmute(_ tab: Tab) {
        contextMenuActionSubject.send(.muteOrUnmute(tab))
        updateTabAudioState(tab: tab)
    }
}
