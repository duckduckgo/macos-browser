//
//  PixelArguments.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

extension Pixel.Event {

    enum AppLaunch: String {
        case initial = "initial"
        case regular = "app-launch"
        case openURL = "open-url"
        case openFile = "open-file"

        private static let AppInitiallyLaunchedKey = "init"

        static func autoInitialOrRegular(store: UserDefaults = .standard, now: Date = Date()) -> AppLaunch {
            let launchRepetition = Repetition(key: Self.AppInitiallyLaunchedKey, store: store, now: now)
            switch launchRepetition {
            case .initial:
                return .initial
            case .dailyFirst, .repetitive:
                return .regular
            }
        }

    }

    enum IsDefaultBrowser: String {

        case `default` = "as-default"
        case nonDefault = "as-nondefault"

        init(isDefault: Bool) {
            self = isDefault ? .default : .nonDefault
        }

        init() {
            self.init(isDefault: Browser.isDefault)
        }
    }

    enum Repetition: String {
        case initial = "initial"
        case dailyFirst = "first-in-a-day"
        case repetitive = "repetitive"

        init(key: String, store: UserDefaults = .standard, now: Date = Date()) {
            let key = "t_" + key
            defer {
                store.set(now.daySinceReferenceDate, forKey: key)
            }

            guard let lastUsedDay = store.value(forKey: key) as? Int else {
                self = .initial
                return
            }
            if lastUsedDay == now.daySinceReferenceDate {
                self = .repetitive
            }
            self = .dailyFirst
        }
    }

    enum AverageTabsCount: String {
        case lessThan6 = "less-than-6-tabs"
        case moreThan6 = "more-than-6-tabs"

        init(avgTabs: Double) {
            if avgTabs >= 6 {
                self = .moreThan6
            }
            self = .lessThan6
        }
    }

    enum BurnedTabs: String {
        case lessThan6 = "burn-less-than-6-tabs"
        case moreThan6 = "burn-more-than-6-tabs"

        init(_ tabs: Int) {
            if tabs >= 6 {
                self = .moreThan6
            }
            self = .lessThan6
        }

        init() {
            let tabCount = WindowControllersManager.shared.mainWindowControllers
                .reduce(0) { $0 + $1.mainViewController.tabCollectionViewModel.tabCollection.tabs.count }
            self.init(tabCount)
        }

    }

    enum BurnedWindows: String {
        case one = "burn-1-window"
        case moreThan1 = "burn-more-than-1-window"

        init(_ windows: Int) {
            if windows <= 1 {
                self = .one
            }
            self = .moreThan1
        }

        init() {
            let windowCount = WindowControllersManager.shared.mainWindowControllers.count
            self.init(windowCount)
        }

    }

    enum FireproofKind: String {
        case bookmarked
        case favorite
        case website

        init(url: URL?, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
            guard let url = url,
                  let bookmark = bookmarkManager.getBookmark(for: url) else {
                self = .website
                return
            }
            if bookmark.isFavorite {
                self = .favorite
            } else {
                self = .bookmarked
            }
        }

    }

    enum FireproofingSuggested: String, ExpressibleByBooleanLiteral {
        case suggested
        case manual

        init(booleanLiteral value: Bool) {
            self = value ? .suggested : .manual
        }
    }

    enum IsBookmarkFireproofed: String, ExpressibleByBooleanLiteral {
        case fireproofed = "fireproofed"
        case nonFireproofed = "non-fireproofed"

        init(booleanLiteral value: Bool) {
            self = value ? .fireproofed : .nonFireproofed
        }
    }

    enum AccessPoint: String {
        case button = "source-button"
        case mainMenu = "source-menu"
        case tabMenu = "source-tab-menu"
        case hotKey = "source-keyboard"
        case moreMenu = "source-more-menu"
    }

    enum NavigationKind: String {
        case search
        case url
        case bookmark
        case favorite
    }

    enum NavigationAccessPoint: String {
        case mainMenu = "source-menu"
        case addressBar = "source-address-bar"
        case suggestion = "source-suggestion"
        case newTab = "source-new-tab"
    }

    enum HasBookmark: String, ExpressibleByBooleanLiteral {
        case hasBookmark = "has-bookmark"
        case noBookmarks = "no-bookmarks"

        init(booleanLiteral value: Bool) {
            self = value ? .hasBookmark : .noBookmarks
        }
    }

    enum HasFavorite: String, ExpressibleByBooleanLiteral {
        case hasFavorite = "has-favorite"
        case noFavorites = "no-favorites"

        init(booleanLiteral value: Bool) {
            self = value ? .hasFavorite : .noFavorites
        }
    }

    enum SharingResult: String {
        case success = "success"
        case failure = "cancelled"
    }

    enum MoreResult: String {
        case cancelled = "cancelled"
        case moveTabToNewWindow = "new-window"
        case feedback = "feedback"
        case bookmark = "bookmark"
        case emailProtection = "email-protection"
        case fireproof = "fireproof"
    }

    enum RefreshAccessPoint: String {
        case hotKey = "source-cmd-r"
        case button = "source-button"
        case mainMenu = "source-menu"
        case reloadURL = "source-url"
    }

}
