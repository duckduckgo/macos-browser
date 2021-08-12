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

    enum AppLaunch: String, CustomStringConvertible {
        var description: String { rawValue }

        case initial = "initial"
        case regular = "app-launch"
        case openURL = "open-url"
        case openFile = "open-file"

        private static let AppInitiallyLaunchedKey = "init"

        static func autoInitialOrRegular(store: PixelDataStore = LocalPixelDataStore.shared, now: Date = Date()) -> AppLaunch {
            let launchRepetition = Repetition(key: Self.AppInitiallyLaunchedKey, store: store, now: now)
            switch launchRepetition {
            case .initial:
                return .initial
            case .dailyFirst, .repetitive:
                return .regular
            }
        }

    }

    enum IsDefaultBrowser: String, CustomStringConvertible {
        var description: String { rawValue }

        case `default` = "as-default"
        case nonDefault = "as-nondefault"

        init(isDefault: Bool) {
            self = isDefault ? .default : .nonDefault
        }

        init() {
            self.init(isDefault: DefaultBrowserPreferences.isDefault)
        }
    }

    enum Repetition: String, CustomStringConvertible {
        var description: String { rawValue }

        case initial = "initial"
        case dailyFirst = "first-in-a-day"
        case repetitive = "repetitive"

        init(key: String, store: PixelDataStore = LocalPixelDataStore.shared, now: Date = Date()) {
            defer {
                store.set(now.daySinceReferenceDate, forKey: key)
            }

            guard let lastUsedDay: Int = store.value(forKey: key) else {
                self = .initial
                return
            }
            if lastUsedDay == now.daySinceReferenceDate {
                self = .repetitive
                return
            }
            self = .dailyFirst
        }
    }

    enum AverageTabsCount: String, CustomStringConvertible {
        var description: String { rawValue }

        case lessThan6 = "less-than-6-tabs"
        case moreThan6 = "more-than-6-tabs"

        init(avgTabs: Double) {
            if avgTabs >= 6 {
                self = .moreThan6
                return
            }
            self = .lessThan6
        }
    }

    enum BurnedTabs: String, CustomStringConvertible {
        var description: String { rawValue }

        case lessThan6 = "burn-less-than-6-tabs"
        case moreThan6 = "burn-more-than-6-tabs"

        init(_ tabs: Int) {
            if tabs >= 6 {
                self = .moreThan6
                return
            }
            self = .lessThan6
        }

        init() {
            let tabCount = WindowControllersManager.shared.mainWindowControllers
                .reduce(0) { $0 + $1.mainViewController.tabCollectionViewModel.tabCollection.tabs.count }
            self.init(tabCount)
        }

    }

    enum BurnedWindows: String, CustomStringConvertible {
        var description: String { rawValue }

        case one = "burn-1-window"
        case moreThan1 = "burn-more-than-1-window"

        init(_ windows: Int) {
            if windows <= 1 {
                self = .one
                return
            }
            self = .moreThan1
        }

        init() {
            let windowCount = WindowControllersManager.shared.mainWindowControllers.count
            self.init(windowCount)
        }

    }

    enum FireproofKind: String, CustomStringConvertible {
        var description: String { rawValue }

        case bookmarked
        case favorite
        case website
        case pwm

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

    enum FireproofingSuggested: String, CustomStringConvertible {
        var description: String { rawValue }

        case suggested
        case manual
        case pwm
    }

    enum IsBookmarkFireproofed: String, CustomStringConvertible {
        var description: String { rawValue }

        case fireproofed = "fireproofed"
        case nonFireproofed = "non-fireproofed"

        init(url: URL?, fireproofDomains: FireproofDomains = .shared) {
            if let host = url?.host,
               fireproofDomains.isFireproof(fireproofDomain: host) {
                self = .fireproofed
            } else {
                self = .nonFireproofed
            }
        }

    }

    enum AccessPoint: String, CustomStringConvertible {
        var description: String { rawValue }

        case button = "source-button"
        case mainMenu = "source-menu"
        case tabMenu = "source-tab-menu"
        case hotKey = "source-keyboard"
        case moreMenu = "source-more-menu"
        case newTab = "source-new-tab"

        init(sender: Any, default: AccessPoint, mainMenuCheck: (NSMenu?) -> Bool = { $0 is MainMenu }) {
            switch sender {
            case let menuItem as NSMenuItem:
                if mainMenuCheck(menuItem.topMenu) {
                    if let event = NSApp.currentEvent,
                        case .keyDown = event.type,
                        event.characters == menuItem.keyEquivalent {

                        self = .hotKey
                    } else {
                        self = .mainMenu
                    }
                } else {
                    self = `default`
                }

            case is NSButton:
                self = .button

            default:
                assertionFailure("AccessPoint: Unexpected type of sender: \(type(of: sender))")
                self = `default`
            }
        }

    }

    enum NavigationKind: String, CustomStringConvertible {
        var description: String { rawValue }

        case search
        case url
        case bookmark
        case favorite

        static func bookmark(isFavorite: Bool) -> NavigationKind {
            if isFavorite {
                return .favorite
            }
            return .bookmark
        }

        init(url: URL?, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
            guard let url = url,
                  !url.isDuckDuckGoSearch else {
                self = .search
                return
            }
            guard let bookmark = bookmarkManager.getBookmark(for: url) else {
                self = .url
                return
            }
            self = .bookmark(isFavorite: bookmark.isFavorite)
        }

    }

    enum NavigationAccessPoint: String, CustomStringConvertible {
        var description: String { rawValue }

        case mainMenu = "source-menu"
        case addressBar = "source-address-bar"
        case suggestion = "source-suggestion"
        case newTab = "source-new-tab"
        case listInterface = "source-list-interface"
        case managementInterface = "source-management-interface"
    }

    enum HasBookmark: String, CustomStringConvertible {
        var description: String { rawValue }

        case hasBookmark = "has-bookmark"
        case noBookmarks = "no-bookmarks"
    }

    enum HasFavorite: String, CustomStringConvertible {
        var description: String { rawValue }

        case hasFavorite = "has-favorite"
        case noFavorites = "no-favorites"
    }

    enum HasHistoryEntry: String, CustomStringConvertible {
        var description: String { rawValue }

        case hasHistoryEntry = "has-history-entry"
        case noHistoryEntry = "no-history-entry"
    }

    enum SharingResult: String, CustomStringConvertible {
        var description: String { rawValue }

        case success
        case failure
        case cancelled
    }

    enum MoreResult: String, CustomStringConvertible {
        var description: String { rawValue }

        case cancelled = "cancelled"
        case moveTabToNewWindow = "new-window"
        case feedback = "feedback"
        case bookmarksList = "bookmarks-list"
        case logins = "logins"
        case emailProtection = "email-protection"
        case fireproof = "fireproof"
        case preferences = "preferences"
    }

    enum RefreshAccessPoint: String, CustomStringConvertible {
        var description: String { rawValue }

        case hotKey = "source-cmd-r"
        case button = "source-button"
        case mainMenu = "source-menu"
        case reloadURL = "source-url"

        init(sender: Any, default: RefreshAccessPoint, mainMenuCheck: (NSMenu?) -> Bool = { $0 is MainMenu }) {
            switch sender {
            case let menuItem as NSMenuItem:
                if mainMenuCheck(menuItem.topMenu) {
                    if let event = NSApp.currentEvent,
                        case .keyDown = event.type,
                        event.characters == menuItem.keyEquivalent {

                        self = .hotKey
                    } else {
                        self = .mainMenu
                    }
                } else {
                    self = `default`
                }

            case is NSButton:
                self = .button

            default:
                assertionFailure("RefreshAccessPoint: Unexpected type of sender: \(type(of: sender))")
                self = `default`
            }
        }
    }

    enum DataImportSource: String, CustomStringConvertible {
        var description: String { rawValue }

        case brave = "source-brave"
        case chrome = "source-chrome"
        case csv = "source-csv"
        case edge = "source-edge"
        case firefox = "source-firefox"
    }

}
