//
//  RecentlyClosedMenu.swift
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

@MainActor
final class RecentlyClosedMenu: NSMenu {

    enum Constants {
        static let maxNumberOfItems = 30
    }

    required init(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    init(recentlyClosedCoordinator: RecentlyClosedCoordinating) {
        super.init(title: "Recently Closed")

        initMenuItems(recentlyClosedCoordinator: recentlyClosedCoordinator)
    }

    private func initMenuItems(recentlyClosedCoordinator: RecentlyClosedCoordinating) {
        var items = [NSMenuItem]()

        recentlyClosedCoordinator.cache.forEach({ cacheItem in
            switch cacheItem {
            case let tab as RecentlyClosedTab:
                if let menuItem = NSMenuItem(recentlyClosedTab: tab) {
                    items.append(menuItem)
                }
            case let window as RecentlyClosedWindow:
                items.append(contentsOf: NSMenuItem.makeMenuItems(recentlyClosedWindow: window).reversed())
            default:
                assertionFailure("Unkown type")
            }
        })

        self.items = Array(items
                            .reversed()
                            .prefix(Constants.maxNumberOfItems))
    }

}

private extension NSMenuItem {

    convenience init?(recentlyClosedTab: RecentlyClosedTab) {
        self.init()

        switch recentlyClosedTab.tabContent {
        case .homePage:
            image = TabViewModel.Favicon.home
            title = UserText.tabHomeTitle
        case .preferences:
            image = TabViewModel.Favicon.preferences
            title = UserText.tabPreferencesTitle
        case .bookmarks:
            image = TabViewModel.Favicon.preferences
            title = UserText.tabPreferencesTitle
        case .url:
            image = recentlyClosedTab.favicon
            image?.size = NSSize.faviconSize
            title = recentlyClosedTab.title ?? recentlyClosedTab.tabContent.url?.absoluteString ?? ""

            if title.count > MainMenu.Constants.maxTitleLength {
                title = String(title.truncated(length: MainMenu.Constants.maxTitleLength))
            }
        case .onboarding, .none:
            return nil
        }

        action = #selector(AppDelegate.recentlyClosedAction(_:))
        representedObject = recentlyClosedTab
    }

    static func makeMenuItems(recentlyClosedWindow: RecentlyClosedWindow) -> [NSMenuItem] {

        func makeHeaderItem(from recentlyClosedWindow: RecentlyClosedWindow) -> NSMenuItem? {
            guard let first = recentlyClosedWindow.tabs.first,
                  let item = NSMenuItem(recentlyClosedTab: first) else {
                return nil
            }

            if recentlyClosedWindow.tabs.count > 1 {
                let moreCount = recentlyClosedWindow.tabs.count - 1
                let titleSuffix: String
                if moreCount == 1 {
                    titleSuffix = UserText.recentlyClosedMenuItemSuffixOne
                } else {
                    titleSuffix = String(format: UserText.recentlyClosedMenuItemSuffixMultiple, moreCount)
                }

                item.title = item.title.truncated(length: MainMenu.Constants.maxTitleLength - titleSuffix.count)
                item.title += titleSuffix
            }
            item.representedObject = recentlyClosedWindow
            return item
        }

        guard !recentlyClosedWindow.tabs.isEmpty, let headerItem = makeHeaderItem(from: recentlyClosedWindow) else {
            return []
        }

        var items = [NSMenuItem]()
        items.append(NSMenuItem.separator())
        items.append(headerItem)
        items.append(NSMenuItem.separator())
        return items
    }

}
