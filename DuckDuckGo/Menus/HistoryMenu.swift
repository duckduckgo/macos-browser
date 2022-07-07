//
//  HistoryMenu.swift
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

import Cocoa
import Combine

final class HistoryMenu: NSMenu {

    @IBOutlet weak var recentlyClosedMenuItem: NSMenuItem?
    @IBOutlet weak var reopenLastClosedMenuItem: NSMenuItem? {
        didSet {
            reopenMenuItemKeyEquivalentManager.reopenLastClosedMenuItem = reopenLastClosedMenuItem
        }
    }
    @IBOutlet weak var reopenAllWindowsFromLastSessionMenuItem: NSMenuItem? {
        didSet {
            reopenMenuItemKeyEquivalentManager.lastSessionMenuItem = reopenAllWindowsFromLastSessionMenuItem
        }
    }

    private var recentlyClosedMenu: RecentlyClosedMenu?
    private let reopenMenuItemKeyEquivalentManager = ReopenMenuItemKeyEquivalentManager()

    override func update() {
        super.update()

        updateRecentlyClosedMenu()
        updateReopenLastClosedMenuItem()
        updateRecentlyVisited()
    }

    // MARK: - Last Closed & Recently Closed

    private func updateReopenLastClosedMenuItem() {
        switch RecentlyClosedCoordinator.shared.cache.last {
        case is RecentlyClosedWindow:
            reopenLastClosedMenuItem?.title = UserText.reopenLastClosedWindow
        default:
            reopenLastClosedMenuItem?.title = UserText.reopenLastClosedTab
        }

    }

    private func updateRecentlyClosedMenu() {
        recentlyClosedMenu = RecentlyClosedMenu(recentlyClosedCoordinator: RecentlyClosedCoordinator.shared)
        recentlyClosedMenuItem?.submenu = recentlyClosedMenu
        recentlyClosedMenuItem?.isEnabled = !(recentlyClosedMenu?.items ?? [] ).isEmpty
    }

    // MARK: - Recently Visited

    var recentlyVisitedHeaderMenuItem: NSMenuItem?
    var recentlyVisitedMenuItems = [NSMenuItem]()

    private func updateRecentlyVisited() {
        updateRecentlyVisitedHeader()
        updateRecentlyVisitedItems()
    }

    private func updateRecentlyVisitedHeader() {
        if let recentlyVisitedHeaderMenuItem = recentlyVisitedHeaderMenuItem {
            if !items.contains(recentlyVisitedHeaderMenuItem) {
                self.recentlyVisitedHeaderMenuItem = nil
            }
        }

        if recentlyVisitedHeaderMenuItem == nil {
            addItem(NSMenuItem.separator())

            let headerItem = NSMenuItem(title: "Recently Visited", action: nil, target: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            addItem(headerItem)
            recentlyVisitedHeaderMenuItem = headerItem
        }
    }

    private func updateRecentlyVisitedItems() {
        items.removeAll { menuItem in
            recentlyVisitedMenuItems.contains(menuItem)
        }

        //HERE
        recentlyVisitedMenuItems = []
    }

}

extension HistoryMenu {
    /**
     * This class manages the shortcut assignment to either of the
     * "Reopen Last Closed Tab" or "Reopen All Windows from Last Session"
     * menu items.
     */
    final class ReopenMenuItemKeyEquivalentManager {
        weak var reopenLastClosedMenuItem: NSMenuItem?
        weak var lastWindowMenuItem: NSMenuItem?
        weak var lastSessionMenuItem: NSMenuItem?

        enum Const {
            static let keyEquivalent = "T"
            static let modifierMask = NSEvent.ModifierFlags.command
        }

        init(
            isInInitialStatePublisher: Published<Bool>.Publisher = WindowControllersManager.shared.$isInInitialState,
            canRestoreLastSessionState: @escaping @autoclosure () -> Bool = NSApp.canRestoreLastSessionState
        ) {
            self.canRestoreLastSessionState = canRestoreLastSessionState
            self.isInInitialStateCancellable = isInInitialStatePublisher
                .dropFirst()
                .removeDuplicates()
                .sink { [weak self] isInInitialState in
                    self?.updateKeyEquivalent(isInInitialState)
                }
        }

        private weak var currentlyAssignedMenuItem: NSMenuItem?
        private var isInInitialStateCancellable: AnyCancellable?
        private var canRestoreLastSessionState: () -> Bool

        private func updateKeyEquivalent(_ isInInitialState: Bool) {
            if isInInitialState && canRestoreLastSessionState() {
                assignKeyEquivalent(to: lastSessionMenuItem)
            } else {
                assignKeyEquivalent(to: reopenLastClosedMenuItem)
            }
        }

        func assignKeyEquivalent(to menuItem: NSMenuItem?) {
            currentlyAssignedMenuItem?.keyEquivalent = ""
            currentlyAssignedMenuItem?.keyEquivalentModifierMask = []
            menuItem?.keyEquivalent = Const.keyEquivalent
            menuItem?.keyEquivalentModifierMask = Const.modifierMask
            currentlyAssignedMenuItem = menuItem
        }
    }
}

private extension NSApplication {
    var canRestoreLastSessionState: Bool {
        (delegate as? AppDelegate)?.stateRestorationManager?.canRestoreLastSessionState ?? false
    }
}
