//
//  SortBookmarksViewModel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import AppKit
import Combine

enum BookmarksSortMode: Codable {
    case manual
    case nameAscending
    case nameDescending

    var title: String {
        switch self {
        case .manual:
            return UserText.bookmarksSortManual
        case .nameAscending:
            return UserText.bookmarksSortByNameAscending
        case .nameDescending:
            return UserText.bookmarksSortByNameDescending
        }
    }

    var action: Selector {
        switch self {
        case .manual:
            return #selector(BookmarkSortMenuItemSelectors.manualSort(_:))
        case .nameAscending:
            return #selector(BookmarkSortMenuItemSelectors.sortByNameAscending(_:))
        case .nameDescending:
            return #selector(BookmarkSortMenuItemSelectors.sortByNameDescending(_:))
        }
    }

    var shouldHighlightButton: Bool {
        return self != .manual
    }

    var menu: NSMenu {
        switch self {
        case .manual:
            return NSMenu(items: [
                menuItem(for: .manual, state: .on),
                sortByName(state: .off),
                NSMenuItem.separator(),
                menuItem(for: .nameAscending, state: .off, disabled: true),
                menuItem(for: .nameDescending, state: .off, disabled: true)
            ])
        case .nameAscending:
            return NSMenu(items: [
                menuItem(for: .manual, state: .off),
                sortByName(state: .on),
                NSMenuItem.separator(),
                menuItem(for: .nameAscending, state: .on),
                menuItem(for: .nameDescending, state: .off)
            ])
        case .nameDescending:
            return NSMenu(items: [
                menuItem(for: .manual, state: .off),
                sortByName(state: .on),
                NSMenuItem.separator(),
                menuItem(for: .nameAscending, state: .off),
                menuItem(for: .nameDescending, state: .on)
            ])
        }
    }

    private func menuItem(for mode: BookmarksSortMode, state: NSControl.StateValue, disabled: Bool = false) -> NSMenuItem {
        return NSMenuItem(title: mode.title, action: disabled ? nil : mode.action, state: state)
    }

    private func sortByName(state: NSControl.StateValue) -> NSMenuItem {
        return NSMenuItem(title: UserText.bookmarksSortByName, action: BookmarksSortMode.nameAscending.action, state: state)
    }
}

protocol SortBookmarksRepository {

    var storedSortMode: BookmarksSortMode { get set }
}

final class SortBookmarksUserDefaults: SortBookmarksRepository {

    private enum Keys {
        static let sortMode = "com.duckduckgo.bookmarks.sort.mode"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var storedSortMode: BookmarksSortMode {
        get {
            if let data = userDefaults.data(forKey: Keys.sortMode),
               let mode = try? JSONDecoder().decode(BookmarksSortMode.self, from: data) {
                return mode
            }
            // Default value if not set
            return .manual
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: Keys.sortMode)
            }
        }
    }
}

final class SortBookmarksViewModel {

    private var repository: SortBookmarksRepository

    @Published
    var selectedSortMode: BookmarksSortMode = .manual {
        didSet {
            repository.storedSortMode = selectedSortMode
        }
    }

    init(repository: SortBookmarksRepository = SortBookmarksUserDefaults()) {
        self.repository = repository

        selectedSortMode = repository.storedSortMode
    }
}
