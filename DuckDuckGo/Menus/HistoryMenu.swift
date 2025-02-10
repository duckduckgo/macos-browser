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

import BrowserServicesKit
import Cocoa
import Combine
import Common
import FeatureFlags
import History
import os.log

final class HistoryMenu: NSMenu {

    let backMenuItem = NSMenuItem(title: UserText.navigateBack, action: #selector(MainViewController.back), keyEquivalent: "[")
    let forwardMenuItem = NSMenuItem(title: UserText.navigateForward, action: #selector(MainViewController.forward), keyEquivalent: "]")

    private let recentlyClosedMenuItem = NSMenuItem(title: UserText.mainMenuHistoryRecentlyClosed)
    private let reopenLastClosedMenuItem = NSMenuItem(title: UserText.reopenLastClosedTab, action: #selector(AppDelegate.reopenLastClosedTab))
    private let reopenAllWindowsFromLastSessionMenuItem = NSMenuItem(title: UserText.mainMenuHistoryReopenAllWindowsFromLastSession,
                                                                     action: #selector(AppDelegate.reopenAllWindowsFromLastSession))
    private let showHistoryMenuItem = NSMenuItem(title: "Show All History…", action: #selector(MainViewController.showHistory), keyEquivalent: "y")
    private let showHistorySeparator = NSMenuItem.separator()
    private let clearAllHistoryMenuItem = NSMenuItem(title: UserText.mainMenuHistoryClearAllHistory,
                                                     action: #selector(MainViewController.clearAllHistory),
                                                     keyEquivalent: [.command, .shift, .backspace])
        .withAccessibilityIdentifier("HistoryMenu.clearAllHistory")
    private let clearAllHistorySeparator = NSMenuItem.separator()

    private let historyGroupingProvider: HistoryGroupingProvider
    private let featureFlagger: FeatureFlagger
    @MainActor
    private let reopenMenuItemKeyEquivalentManager = ReopenMenuItemKeyEquivalentManager()

    @MainActor
    init(historyGroupingProvider: HistoryGroupingProvider = .init(dataSource: HistoryCoordinator.shared), featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger) {
        self.historyGroupingProvider = historyGroupingProvider
        self.featureFlagger = featureFlagger

        super.init(title: UserText.mainMenuHistory)

        self.buildItems {
            backMenuItem
            forwardMenuItem
            NSMenuItem.separator()

            reopenLastClosedMenuItem
            recentlyClosedMenuItem
            reopenAllWindowsFromLastSessionMenuItem

            showHistorySeparator
            showHistoryMenuItem
            clearAllHistorySeparator
            clearAllHistoryMenuItem
        }

        reopenMenuItemKeyEquivalentManager.reopenLastClosedMenuItem = reopenLastClosedMenuItem
        reopenAllWindowsFromLastSessionMenuItem.setAccessibilityIdentifier("HistoryMenu.reopenAllWindowsFromLastSessionMenuItem")
        reopenMenuItemKeyEquivalentManager.lastSessionMenuItem = reopenAllWindowsFromLastSessionMenuItem
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    override func update() {
        super.update()

        showHistoryMenuItem.isHidden = !featureFlagger.isFeatureOn(.historyView)

        updateRecentlyClosedMenu()
        updateReopenLastClosedMenuItem()

        clearOldVariableMenuItems()
        addRecentlyVisited()
        addHistoryGroupings()
        addClearAllAndShowHistoryOnTheBottom()
    }

    private func clearOldVariableMenuItems() {
        items.removeAll { menuItem in
            recentlyVisitedMenuItems.contains(menuItem) ||
            historyGroupingsMenuItems.contains(menuItem) ||
            menuItem == clearAllHistoryMenuItem ||
            menuItem == showHistoryMenuItem
        }
    }

    // MARK: - Last Closed & Recently Closed

    @MainActor
    private func updateReopenLastClosedMenuItem() {
        switch RecentlyClosedCoordinator.shared.cache.last {
        case is RecentlyClosedWindow:
            reopenLastClosedMenuItem.title = UserText.reopenLastClosedWindow
            reopenLastClosedMenuItem.setAccessibilityIdentifier("HistoryMenu.reopenLastClosedWindow")
        default:
            reopenLastClosedMenuItem.title = UserText.reopenLastClosedTab
            reopenLastClosedMenuItem.setAccessibilityIdentifier("HistoryMenu.reopenLastClosedTab")
        }

    }

    @MainActor
    private func updateRecentlyClosedMenu() {
        let recentlyClosedMenu = RecentlyClosedMenu(recentlyClosedCoordinator: RecentlyClosedCoordinator.shared)
        recentlyClosedMenuItem.submenu = recentlyClosedMenu
        recentlyClosedMenuItem.isEnabled = !recentlyClosedMenu.items.isEmpty
    }

    // MARK: - Recently Visited

    var recentlyVisitedHeaderMenuItem: NSMenuItem {
        let item = NSMenuItem(title: UserText.recentlyVisitedMenuSection)
        item.isEnabled = false
        item.setAccessibilityIdentifier("HistoryMenu.recentlyVisitedHeaderMenuItem")
        return item
    }

    private var recentlyVisitedMenuItems = [NSMenuItem]()

    private func addRecentlyVisited() {
        recentlyVisitedMenuItems = [recentlyVisitedHeaderMenuItem]
        let recentVisits = historyGroupingProvider.getRecentVisits(maxCount: 14)
        for (index, visit) in zip(
            recentVisits.indices, recentVisits
        ) {
            let visitMenuItem = VisitMenuItem(visitViewModel: VisitViewModel(visit: visit))
            visitMenuItem.setAccessibilityIdentifier("HistoryMenu.recentlyVisitedMenuItem.\(index)")
            recentlyVisitedMenuItems.append(visitMenuItem)
        }
        for recentlyVisitedMenuItem in recentlyVisitedMenuItems {
            addItem(recentlyVisitedMenuItem)
        }
    }

    // MARK: - History Groupings

    private var historyGroupingsMenuItems = [NSMenuItem]()

    private func addHistoryGroupings() {
        let groupings = historyGroupingProvider.getVisitGroupings()
        var firstWeek = [HistoryGrouping](), older = [HistoryGrouping]()
        groupings.forEach { grouping in
            if grouping.date > Date.weekAgo.startOfDay {
                firstWeek.append(grouping)
            } else if !featureFlagger.isFeatureOn(.historyView) {
                older.append(grouping)
            }
        }

        historyGroupingsMenuItems = [NSMenuItem.separator()]

        // First week
        let firstWeekMenuItems = makeGroupingMenuItems(from: firstWeek)
        historyGroupingsMenuItems.append(contentsOf: firstWeekMenuItems)

        // Older
        let olderMenuItems = makeGroupingMenuItems(from: older)
        if let olderRootMenuItem = makeOlderRootMenuItem(from: olderMenuItems) {
            historyGroupingsMenuItems.append(olderRootMenuItem)
        }

        historyGroupingsMenuItems.forEach {
            addItem($0)
        }
    }

    private func makeGroupingMenuItems(from groupings: [HistoryGrouping]) -> [NSMenuItem] {

        func makeGroupingRootMenuItem(from grouping: HistoryGrouping) -> NSMenuItem {
            let title = makeTitle(for: grouping)
            let menuItem = NSMenuItem(title: "\(title.0), \(title.1)")
            let isToday = NSCalendar.current.isDateInToday(grouping.date)
            let dateString = isToday ? nil : title.1
            let subMenuItems = makeClearThisHistoryMenuItems(with: dateString) + makeMenuItems(from: grouping)
            let submenu = NSMenu(items: subMenuItems)
            menuItem.submenu = submenu
            return menuItem
        }

        return groupings.map { grouping in
            makeGroupingRootMenuItem(from: grouping)
        }
    }

    private func makeOlderRootMenuItem(from submenuItems: [NSMenuItem]) -> NSMenuItem? {
        guard submenuItems.count > 0 else {
            return nil
        }

        let rootMenuItem = NSMenuItem(title: UserText.olderMenuItem)
        rootMenuItem.submenu = NSMenu(items: submenuItems)
        return rootMenuItem
    }

    private func makeMenuItems(from grouping: HistoryGrouping) -> [NSMenuItem] {
        let date = grouping.date
        let isToday = NSCalendar.current.isDateInToday(date)
        let visits = grouping.visits
        var menuItems = [NSMenuItem]()
        for (index, visit) in zip(
            visits.indices, visits
        ) {
            let menuItem = VisitMenuItem(visitViewModel: VisitViewModel(visit: visit))
            menuItem.setAccessibilityIdentifier("HistoryMenu.historyMenuItem.\(isToday ? "Today" : "\(date)").\(index)")
            menuItems.append(menuItem)
        }
        return menuItems
    }

    private func makeTitle(for grouping: HistoryGrouping) -> (String, String) {
        let prefix: String
        if grouping.date > Date.daysAgo(2).startOfDay {
            prefix = relativePrefixFormatter.string(from: grouping.date)
        } else {
            prefix = prefixFormatter.string(from: grouping.date)
        }
        let suffix = suffixFormatter.string(from: grouping.date)
        return (prefix, suffix)
    }

    let relativePrefixFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()

    let suffixFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, YYYY"
        return dateFormatter
    }()

    let prefixFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter
    }()

    private func makeClearThisHistoryMenuItems(with dateString: String?) -> [NSMenuItem] {
        let headerItem = ClearThisHistoryMenuItem(title: UserText.clearThisHistoryMenuItem,
                                                  action: #selector(AppDelegate.clearThisHistory(_:)),
                                                  keyEquivalent: "")
        let historyTimeWindow = ClearThisHistoryMenuItem.HistoryTimeWindow(dateString: dateString)
        headerItem.setRepresentingObject(historyTimeWindow: historyTimeWindow)
        return [
            headerItem,
            .separator()
        ]
    }

    // MARK: - Clear All History

    private func addClearAllAndShowHistoryOnTheBottom() {
        if featureFlagger.isFeatureOn(.historyView) {
            if showHistorySeparator.menu != nil {
                removeItem(showHistorySeparator)
            }
            addItem(showHistorySeparator)
            addItem(showHistoryMenuItem)
        }
        if clearAllHistorySeparator.menu != nil {
            removeItem(clearAllHistorySeparator)
        }
        addItem(clearAllHistorySeparator)
        addItem(clearAllHistoryMenuItem)
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

        init(isInInitialStatePublisher: Published<Bool>.Publisher, canRestoreLastSessionState: @escaping @autoclosure () -> Bool) {
            self.canRestoreLastSessionState = canRestoreLastSessionState
            self.isInInitialStateCancellable = isInInitialStatePublisher
                .dropFirst()
                .removeDuplicates()
                .sink { [weak self] isInInitialState in
                    self?.updateKeyEquivalent(isInInitialState)
                }
        }

        @MainActor
        convenience init() {
            self.init(isInInitialStatePublisher: WindowControllersManager.shared.$isInInitialState, canRestoreLastSessionState: NSApp.canRestoreLastSessionState)
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
        delegateTyped.stateRestorationManager?.canRestoreLastSessionState ?? false
    }

}
