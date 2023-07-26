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

    static func replace(_ menuItem: NSMenuItem?, _ prefs: AppearancePreferences = .shared) -> NSMenuItem? {
        assert(menuItem != nil)
        guard let menuItem, let menu = menuItem.menu else {
            return nil
        }

        let index = menu.index(of: menuItem)
        guard index >= 0 else {
            return nil
        }

        let item = makeMenuItem(prefs)
        menu.replaceItem(at: index, with: item)
        return item
    }

    static func addToMenu(_ menu: NSMenu, _ prefs: AppearancePreferences = .shared) {
        menu.addItem(makeMenuItem(prefs))
    }

    private static func makeMenuItem( _ prefs: AppearancePreferences) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.showBookmarksBar, action: nil, keyEquivalent: "B")
        item.submenu = NSMenu(items: [
            BlockMenuItem(title: UserText.showBookmarksBarAlways, isChecked: prefs.showBookmarksBar && prefs.bookmarksBarAppearance == .alwaysOn) {
                prefs.bookmarksBarAppearance = .alwaysOn
                prefs.showBookmarksBar = true
            },
            BlockMenuItem(title: UserText.showBookmarksBarNewTabOnly, isChecked: prefs.showBookmarksBar && prefs.bookmarksBarAppearance == .newTabOnly) {
                prefs.bookmarksBarAppearance = .newTabOnly
                prefs.showBookmarksBar = true
            },
            BlockMenuItem(title: UserText.showBookmarksBarNever, isChecked: !prefs.showBookmarksBar) {
                prefs.showBookmarksBar = false
            }
        ])
        return item
    }

}

final class BlockMenuItem: NSMenuItem {
    var block: (() -> Void)?

    convenience init(title: String, keyEquivalent: String = "", isChecked: Bool, block: (() -> Void)?) {
        self.init(title: title, action: #selector(performBlockAction(_:)), keyEquivalent: keyEquivalent)
        self.block = block
        self.target = self
        self.state = isChecked ? .on : .off
    }

    @objc func performBlockAction(_ sender: NSMenuItem) {
        block?()
    }
}
