//
//  PinnedTabsModel.swift
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

final class PinnedTabsModel: ObservableObject {

    enum ContextMenuAction {
        case unpin(Int)
        case duplicate(Int)
        case bookmark(Tab)
        case fireproof(Tab)
        case removeFireproofing(Tab)
        case close(Int)
    }

    @Published var items: [Tab] = [] {
        didSet {
            if oldValue != items && Set(oldValue) == Set(items) {
                tabsDidReorderSubject.send(items)
            }
        }
    }

    @Published var selectedItem: Tab?

    let contextMenuActionPublisher: AnyPublisher<ContextMenuAction, Never>
    let tabsDidReorderPublisher: AnyPublisher<[Tab], Never>

    func isFireproof(_ tab: Tab) -> Bool {
        guard let host = tab.url?.host else {
            os_log("PinnedTabsModel: Failed to get url of a tab", type: .error)
            return false
        }
        return FireproofDomains.shared.isFireproof(fireproofDomain: host)
    }

    func unpin(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            os_log("PinnedTabsModel: Failed to get index of a tab", type: .error)
            return
        }
        contextMenuActionSubject.send(.unpin(index))
    }

    func duplicate(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            os_log("PinnedTabsModel: Failed to get index of a tab", type: .error)
            return
        }
        contextMenuActionSubject.send(.duplicate(index))
    }

    func close(_ tab: Tab) {
        guard let index = items.firstIndex(of: tab) else {
            os_log("PinnedTabsModel: Failed to get index of a tab", type: .error)
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

    // MARK: -

    init(collection: TabCollection) {
        tabsDidReorderPublisher = tabsDidReorderSubject.eraseToAnyPublisher()
        contextMenuActionPublisher = contextMenuActionSubject.eraseToAnyPublisher()
        collection.$tabs
            .assign(to: \.items, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private let tabsDidReorderSubject = PassthroughSubject<[Tab], Never>()
    private let contextMenuActionSubject = PassthroughSubject<ContextMenuAction, Never>()
    private var cancellables = Set<AnyCancellable>()
}
