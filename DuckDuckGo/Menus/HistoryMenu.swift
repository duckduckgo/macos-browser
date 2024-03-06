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
import Common
import History

@MainActor
final class HistoryMenu: NSMenu {

    let backMenuItem = NSMenuItem(title: UserText.navigateBack, action: #selector(MainViewController.back), keyEquivalent: "[")
    let forwardMenuItem = NSMenuItem(title: UserText.navigateForward, action: #selector(MainViewController.forward), keyEquivalent: "]")

    private let recentlyClosedMenuItem = NSMenuItem(title: UserText.mainMenuHistoryRecentlyClosed)
    private let reopenLastClosedMenuItem = NSMenuItem(title: UserText.reopenLastClosedTab, action: #selector(AppDelegate.reopenLastClosedTab))
    private let reopenAllWindowsFromLastSessionMenuItem = NSMenuItem(title: UserText.mainMenuHistoryReopenAllWindowsFromLastSession,
                                                                     action: #selector(AppDelegate.reopenAllWindowsFromLastSession))
    private let clearAllHistoryMenuItem = NSMenuItem(title: UserText.mainMenuHistoryClearAllHistory,
                                                     action: #selector(MainViewController.clearAllHistory),
                                                     keyEquivalent: [.command, .shift, .backspace])
    private let clearAllHistorySeparator = NSMenuItem.separator()

    private let historyCoordinator: HistoryCoordinating
    private let reopenMenuItemKeyEquivalentManager = ReopenMenuItemKeyEquivalentManager()

    init(historyCoordinator: HistoryCoordinating = HistoryCoordinator.shared) {
        self.historyCoordinator = historyCoordinator

        super.init(title: UserText.mainMenuHistory)

        self.buildItems {
            backMenuItem
            forwardMenuItem
            NSMenuItem.separator()

            reopenLastClosedMenuItem
            recentlyClosedMenuItem
            reopenAllWindowsFromLastSessionMenuItem
            NSMenuItem.separator()
        }

        reopenMenuItemKeyEquivalentManager.reopenLastClosedMenuItem = reopenLastClosedMenuItem
        reopenMenuItemKeyEquivalentManager.lastSessionMenuItem = reopenAllWindowsFromLastSessionMenuItem
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        super.update()

        updateRecentlyClosedMenu()
        updateReopenLastClosedMenuItem()

        clearOldVariableMenuItems()
        addRecentlyVisited()
        addHistoryGroupings()
        addClearAllHistoryOnTheBottom()
    }

    private func clearOldVariableMenuItems() {
        items.removeAll { menuItem in
            recentlyVisitedMenuItems.contains(menuItem) ||
            historyGroupingsMenuItems.contains(menuItem) ||
            menuItem == clearAllHistoryMenuItem
        }
    }

    // MARK: - Last Closed & Recently Closed

    private func updateReopenLastClosedMenuItem() {
        switch RecentlyClosedCoordinator.shared.cache.last {
        case is RecentlyClosedWindow:
            reopenLastClosedMenuItem.title = UserText.reopenLastClosedWindow
        default:
            reopenLastClosedMenuItem.title = UserText.reopenLastClosedTab
        }

    }

    private func updateRecentlyClosedMenu() {
        let recentlyClosedMenu = RecentlyClosedMenu(recentlyClosedCoordinator: RecentlyClosedCoordinator.shared)
        recentlyClosedMenuItem.submenu = recentlyClosedMenu
        recentlyClosedMenuItem.isEnabled = !recentlyClosedMenu.items.isEmpty
    }

    // MARK: - Recently Visited

    var recentlyVisitedHeaderMenuItem: NSMenuItem {
        let item = NSMenuItem(title: UserText.recentlyVisitedMenuSection)
        item.isEnabled = false
        return item
    }

    private var recentlyVisitedMenuItems = [NSMenuItem]()

    private func addRecentlyVisited() {
        recentlyVisitedMenuItems = [recentlyVisitedHeaderMenuItem]
        recentlyVisitedMenuItems.append(contentsOf: historyCoordinator.getRecentVisits(maxCount: 14)
            .map {
                VisitMenuItem(visitViewModel: VisitViewModel(visit: $0))
            }
        )
        recentlyVisitedMenuItems.forEach {
            addItem($0)
        }
    }

    // MARK: - History Groupings

    struct HistoryGrouping {
        let date: Date
        let visits: [Visit]
    }

    private var historyGroupingsMenuItems = [NSMenuItem]()

    private func addHistoryGroupings() {
        let groupings = historyCoordinator.getVisitGroupings()
        var firstWeek = [HistoryGrouping](), older = [HistoryGrouping]()
        groupings.forEach { grouping in
            if grouping.date > Date.weekAgo.startOfDay {
                firstWeek.append(grouping)
            } else {
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
        return grouping.visits.map { visit in
            VisitMenuItem(visitViewModel: VisitViewModel(visit: visit))
        }
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
        headerItem.setDateString(dateString)
        return [
            headerItem,
            .separator()
        ]
    }

    // MARK: - Clear All History

    private func addClearAllHistoryOnTheBottom() {
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

private extension HistoryCoordinating {

    func getSortedArrayOfVisits() -> [Visit] {
        guard let history = history else {
            os_log("HistoryCoordinator: No history available", type: .error)
            return []
        }

        return Array(history
            .flatMap { entry in
                Array(entry.visits)
            }
            .sorted(by: { (visit1, visit2) in
                visit1.date > visit2.date
            }))
    }

    func getRecentVisits(maxCount: Int) -> [Visit] {
        return Array(getSortedArrayOfVisits()
            .prefix(maxCount)
            .filter { NSCalendar.current.isDateInToday($0.date) }
        )
    }

    func getVisitGroupings() -> [HistoryMenu.HistoryGrouping] {
        return Dictionary(grouping: getSortedArrayOfVisits()) { visit in
            return visit.date.startOfDay
        } .map {
            return HistoryMenu.HistoryGrouping(date: $0.key, visits: $0.value)
        } .sorted(by: { (grouping1, grouping2) in
            grouping1.date > grouping2.date
        })
    }

}
