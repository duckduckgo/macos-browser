//
//  HomeButtonMenuFactory.swift
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
import AppKit

struct HomeButtonMenuFactory {

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

    private static func makeMenuItem( _ prefs: AppearancePreferences) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.mainMenuHomeButton)

        let isButtonVisible = LocalPinningManager.shared.isPinned(.homeButton)
        let buttonPosition = AppearancePreferences.shared.homeButtonPosition

        let hiddenItem: NSMenuItem = BlockMenuItem(title: UserText.mainMenuHomeButtonMode(for: .hidden), isChecked: !isButtonVisible, block: {
            AppearancePreferences.shared.homeButtonPosition = .hidden
            LocalPinningManager.shared.unpin(.homeButton)
        })
        let leftItem: NSMenuItem = BlockMenuItem(title: UserText.mainMenuHomeButtonMode(for: .left), isChecked: isButtonVisible && buttonPosition == .left, block: {
            AppearancePreferences.shared.homeButtonPosition = .left
            LocalPinningManager.shared.unpin(.homeButton)
            LocalPinningManager.shared.pin(.homeButton)
        })
        let rightItem: NSMenuItem = BlockMenuItem(title: UserText.mainMenuHomeButtonMode(for: .right), isChecked: isButtonVisible && buttonPosition == .right, block: {
            AppearancePreferences.shared.homeButtonPosition = .right
            LocalPinningManager.shared.unpin(.homeButton)
            LocalPinningManager.shared.pin(.homeButton)
        })

        item.submenu = NSMenu(items: [hiddenItem, leftItem, rightItem])
        return item
    }

}
