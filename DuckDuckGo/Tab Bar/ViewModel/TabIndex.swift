//
//  TabIndex.swift
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

enum TabIndex: Equatable, Comparable {
    case pinned(Int), unpinned(Int)

    var index: Int {
        switch self {
        case .pinned(let index), .unpinned(let index):
            return index
        }
    }

    var isPinnedTab: Bool {
        if case .pinned = self {
            return true
        }
        return false
    }

    var isUnpinnedTab: Bool {
        !isPinnedTab
    }

    /**
     * Creates a new tab index by incrementing internal index by 1.
     *
     * No bounds checking is performed.
     */
    func makeNext() -> TabIndex {
        switch self {
        case let .pinned(index):
            return .pinned(index + 1)
        case let .unpinned(index):
            return .unpinned(index + 1)
        }
    }

    static func < (_ lhs: TabIndex, _ rhs: TabIndex) -> Bool {
        switch (lhs, rhs) {
        case (.pinned, .unpinned):
            return true
        case (.unpinned, .pinned):
            return false
        default:
            return lhs.index < rhs.index
        }
    }
}

// MARK: - Tab Collection View Model index manipulation

extension TabIndex {
    static func first(in viewModel: TabCollectionViewModel) -> TabIndex {
        return viewModel.pinnedTabsCount > 0 ? .pinned(0) : .unpinned(0)
    }

    func next(in viewModel: TabCollectionViewModel) -> TabIndex {
        switch self {
        case .pinned(let index):
            if index >= viewModel.pinnedTabsCount - 1 {
                return .unpinned(0)
            }
            return .pinned(index + 1)
        case .unpinned(let index):
            if index >= viewModel.tabCollection.tabs.count - 1 {
                return .first(in: viewModel)
            }
            return .unpinned(index + 1)
        }
    }

    func previous(in viewModel: TabCollectionViewModel) -> TabIndex {
        switch self {
        case .pinned(let index):
            if index == 0 {
                return .unpinned(viewModel.tabsCount - 1)
            }
            return .pinned(index - 1)
        case .unpinned(let index):
            if index == 0 {
                return viewModel.pinnedTabsCount > 0 ? .pinned(viewModel.pinnedTabsCount - 1) : .unpinned(viewModel.tabsCount - 1)
            }
            return .unpinned(index - 1)
        }
    }

    func sanitized(for viewModel: TabCollectionViewModel) -> TabIndex {
        switch self {
        case .pinned(let index):
            if index >= viewModel.pinnedTabsCount {
                return .unpinned(min(index - viewModel.pinnedTabsCount, viewModel.tabsCount - 1))
            }
            return .pinned(max(0, index))
        case .unpinned(let index):
            return .unpinned(max(0, min(index, viewModel.tabsCount - 1)))
        }
    }
}

private extension TabCollectionViewModel {
    var tabsCount: Int {
        tabCollection.tabs.count
    }

    var pinnedTabsCount: Int {
        pinnedTabsCollection.tabs.count
    }
}
