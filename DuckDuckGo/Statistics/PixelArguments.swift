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
import AppKit

extension Pixel.Event {

    enum AppLaunch: String, CustomStringConvertible {
        var description: String { rawValue }

        case initial = "initial"
        case dailyFirst = "first-in-a-day"
        case regular = "app-launch"
        case openURL = "open-url"
        case openFile = "open-file"

        struct AppLaunchRepetition {
            let store: PixelDataStore
            let now: () -> Date

            private static let AppInitiallyLaunchedKey = "init"

            var value: Repetition {
                Repetition(key: Self.AppInitiallyLaunchedKey, store: store, now: now(), update: false)
            }

            func update() {
                _=Repetition(key: Self.AppInitiallyLaunchedKey, store: store, now: now(), update: true)
            }
        }

        static func repetition(store: PixelDataStore = LocalPixelDataStore.shared,
                               now: @autoclosure @escaping () -> Date = Date()) -> AppLaunchRepetition {
            return AppLaunchRepetition(store: store, now: now)
        }

        static func autoInitialOrRegular(store: PixelDataStore = LocalPixelDataStore.shared,
                                         now: @autoclosure @escaping () -> Date = Date()) -> AppLaunch {
            let repetition = self.repetition(store: store, now: now())
            switch repetition.value {
            case .initial:
                return .initial
            case .dailyFirst:
                return .dailyFirst
            case .repetitive:
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
            self.init(isDefault: DefaultBrowserPreferences().isDefault)
        }
    }

    enum Repetition: String, CustomStringConvertible {
        var description: String { rawValue }

        case initial = "initial"
        case dailyFirst = "first-in-a-day"
        case repetitive = "repetitive"

        init(key: String, store: PixelDataStore = LocalPixelDataStore.shared, now: Date = Date(), update: Bool = true) {
            defer {
                if update {
                    store.set(now.daySinceReferenceDate, forKey: key)
                }
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

        @MainActor
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

        @MainActor
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
                  let bookmark = bookmarkManager.getBookmark(forUrl: url.absoluteString) else {
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

        init(url: URL?, fireproofDomains: FireproofDomains = FireproofDomains.shared) {
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

    enum FormAutofillKind: String, CustomStringConvertible {
        var description: String { rawValue }

        case password
        case card
        case identity
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

    enum DataImportAction: String, CustomStringConvertible {
        var description: String { rawValue }

        case importBookmarks = "bookmarks"
        case importLogins = "logins"
        case generic = "generic"
    }

    enum DataImportSource: String, CustomStringConvertible {
        var description: String { rawValue }

        case brave = "source-brave"
        case chrome = "source-chrome"
        case csv = "source-csv"
        case lastPass = "source-lastpass"
        case onePassword = "source-1password"
        case edge = "source-edge"
        case firefox = "source-firefox"
        case safari = "source-safari"
        case bookmarksHTML = "source-bookmarks-html"
    }

    public enum CompileRulesListType: String, CustomStringConvertible {

        public var description: String { rawValue }

        case tds = "tracker_data"
        case clickToLoad = "click_to_load"
        case blockingAttribution = "blocking_attribution"
        case attributed = "attributed"
        case unknown = "unknown"

    }
}
