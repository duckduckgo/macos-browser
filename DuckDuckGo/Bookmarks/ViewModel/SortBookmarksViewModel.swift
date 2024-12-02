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

    var isNameSorting: Bool {
        return self == .nameAscending || self == .nameDescending
    }

    var isReorderingEnabled: Bool{
        return self == .manual
    }

    func menu(target: AnyObject) -> NSMenu {
        switch self {
        case .manual:
            return NSMenu(items: [
                menuItem(for: .manual, state: .on, target: target),
                sortByName(state: .off, target: target),
                NSMenuItem.separator(),
                menuItem(for: .nameAscending, state: .off, target: target, disabled: true),
                menuItem(for: .nameDescending, state: .off, target: target, disabled: true)
            ])
        case .nameAscending:
            return NSMenu(items: [
                menuItem(for: .manual, state: .off, target: target),
                sortByName(state: .on, target: target),
                NSMenuItem.separator(),
                menuItem(for: .nameAscending, state: .on, target: target),
                menuItem(for: .nameDescending, state: .off, target: target)
            ])
        case .nameDescending:
            return NSMenu(items: [
                menuItem(for: .manual, state: .off, target: target),
                sortByName(state: .on, target: target),
                NSMenuItem.separator(),
                menuItem(for: .nameAscending, state: .off, target: target),
                menuItem(for: .nameDescending, state: .on, target: target)
            ])
        }
    }

    private func menuItem(for mode: BookmarksSortMode, state: NSControl.StateValue, target: AnyObject, disabled: Bool = false) -> NSMenuItem {
        return NSMenuItem(title: mode.title, action: disabled ? nil : mode.action, target: target, state: state)
    }

    private func sortByName(state: NSControl.StateValue, target: AnyObject) -> NSMenuItem {
        return NSMenuItem(title: UserText.bookmarksSortByName, action: BookmarksSortMode.nameAscending.action, target: target, state: state)
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
    private var sortModeSubject = PassthroughSubject<BookmarksSortMode, Never>()

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

final class SortBookmarksViewModel: NSObject {

    let metrics: BookmarksSearchAndSortMetrics
    private let origin: BookmarkOperationOrigin
    private var manager: BookmarkManager
    private var wasSortOptionSelected = false
    private var cancellables = Set<AnyCancellable>()

    @Published
    private(set) var selectedSortMode: BookmarksSortMode

    var menu: NSMenu {
        let menu = selectedSortMode.menu(target: self)
        menu.delegate = self
        return menu
    }

    init(manager: BookmarkManager,
         metrics: BookmarksSearchAndSortMetrics,
         origin: BookmarkOperationOrigin) {
        self.metrics = metrics
        self.origin = origin
        self.manager = manager

        selectedSortMode = manager.sortMode

        super.init()

        manager.sortModePublisher
            .receive(on: RunLoop.main)
            .assign(to: \.selectedSortMode, on: self)
            .store(in: &cancellables)
    }

    func setSort(mode: BookmarksSortMode) {
        wasSortOptionSelected = true
        manager.sortMode = mode

        if mode.isNameSorting {
            metrics.fireSortByName(origin: origin)
        }
    }
}

extension SortBookmarksViewModel: NSMenuDelegate {

    func menuDidClose(_ menu: NSMenu) {
        if !wasSortOptionSelected {
            metrics.fireSortButtonDismissed(origin: origin)
        }

        wasSortOptionSelected = false
    }
}

extension SortBookmarksViewModel: BookmarkSortMenuItemSelectors {

    func manualSort(_ sender: NSMenuItem) {
        setSort(mode: .manual)
    }

    func sortByNameAscending(_ sender: NSMenuItem) {
        setSort(mode: .nameAscending)
    }

    func sortByNameDescending(_ sender: NSMenuItem) {
        setSort(mode: .nameDescending)
    }
}
