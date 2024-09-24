//
//  BookmarksBarMenuFactory.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

struct BookmarksBarMenuFactory {

    static func replace(_ menuItem: NSMenuItem, _ prefs: AppearancePreferences = .shared) -> NSMenuItem? {
        guard let menu = menuItem.menu else { return nil }
        let index = menu.index(of: menuItem)
        guard index >= 0 else { return nil }

        let item = makeMenuItem(prefs)
        menu.replaceItem(at: index, with: item)
        return item
    }

    static func addToMenu(_ menu: NSMenu, _ prefs: AppearancePreferences = .shared) {
        menu.addItem(makeMenuItem(prefs))
    }

    static func addToMenuWithManageBookmarksSection(_ menu: NSMenu, target: AnyObject, addFolderSelector: Selector, manageBookmarksSelector: Selector, prefs: AppearancePreferences = .shared) {
        addToMenu(menu, prefs)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: UserText.addFolder, action: addFolderSelector, target: target))
        menu.addItem(NSMenuItem(title: UserText.bookmarksManageBookmarks, action: manageBookmarksSelector, target: target))
    }

    private static func makeMenuItem( _ prefs: AppearancePreferences) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.showBookmarksBar, action: nil, keyEquivalent: "B")
        item.submenu = NSMenu(items: [
            BlockMenuItem(title: UserText.mainMenuBookmarksShowBookmarksBarAlways, isChecked: prefs.showBookmarksBar && prefs.bookmarksBarAppearance == .alwaysOn) {
                prefs.bookmarksBarAppearance = .alwaysOn
                prefs.showBookmarksBar = true
            },
            BlockMenuItem(title: UserText.mainMenuBookmarksShowBookmarksBarNewTabOnly, isChecked: prefs.showBookmarksBar && prefs.bookmarksBarAppearance == .newTabOnly) {
                prefs.bookmarksBarAppearance = .newTabOnly
                prefs.showBookmarksBar = true
            },
            BlockMenuItem(title: UserText.mainMenuBookmarksShowBookmarksBarNever, isChecked: !prefs.showBookmarksBar) {
                prefs.showBookmarksBar = false
            },
            NSMenuItem.separator(),
            BlockMenuItem(title: UserText.mainMenuBookmarksLeftAlignBookmarksBar, isChecked: !prefs.centerAlignedBookmarksBarBool) {
                prefs.centerAlignedBookmarksBarBool = false
            },
            BlockMenuItem(title: UserText.mainMenuBookmarksCenterAlignBookmarksBar, isChecked: prefs.centerAlignedBookmarksBarBool) {
                prefs.centerAlignedBookmarksBarBool = true
            }
        ])

        return item
    }

}
