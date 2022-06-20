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

final class RecentlyClosedMenu: NSMenu {

    enum Constants {
        static let maxNumberOfItems = 30
    }

    required init(coder: NSCoder) {
        fatalError("RecentlyClosedMenu: Bad initializer")
    }

    init(recentlyClosedCoordinator: RecentlyClosedCoordinatorProtocol) {
        super.init(title: "Recently Closed")

        items = Array(recentlyClosedCoordinator.cache
                        .enumerated()
                        .compactMap { NSMenuItem(from: $0.element, cacheIndex: $0.offset) }
                        .reversed()
                        .prefix(Constants.maxNumberOfItems))
    }

}

private extension NSMenuItem {

    convenience init?(from recentlyClosedCacheItem: RecentlyClosedCacheItem, cacheIndex: Int) {
        self.init()

        switch recentlyClosedCacheItem.tabContent {
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
            image = recentlyClosedCacheItem.favicon
            image?.size = NSSize.faviconSize
            title = recentlyClosedCacheItem.title ?? recentlyClosedCacheItem.tabContent.url?.absoluteString ?? ""

            if title.count > MainMenu.Constants.maxTitleLength {
                title = String(title.truncated(length: MainMenu.Constants.maxTitleLength))
            }
        case .onboarding, .none:
            return nil
        }

        action = #selector(AppDelegate.recentlyClosedAction(_:))
        representedObject = cacheIndex
    }

}
