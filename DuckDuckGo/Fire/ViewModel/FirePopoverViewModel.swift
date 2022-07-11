//
//  FirePopoverViewModel.swift
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

import Cocoa
import BrowserServicesKit

final class FirePopoverViewModel {

    enum ClearingOption: CaseIterable {

        case currentTab
        case currentWindow
        case allData

        var string: String {
            switch self {
            case .currentTab: return UserText.currentTab
            case .currentWindow: return UserText.currentWindow
            case .allData: return UserText.allData
            }
        }

    }

    struct Item {
        var domain: String
        var favicon: NSImage?
    }

    init(fireViewModel: FireViewModel,
         tabCollectionViewModel: TabCollectionViewModel,
         historyCoordinating: HistoryCoordinating,
         fireproofDomains: FireproofDomains,
         faviconManagement: FaviconManagement,
         initialClearingOption: ClearingOption = .allData) {
        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel
        self.historyCoordinating = historyCoordinating
        self.fireproofDomains = fireproofDomains
        self.faviconManagement = faviconManagement
        self.clearingOption = initialClearingOption

        self.pinnedDomains = Set(tabCollectionViewModel.pinnedTabsCollection.tabs.compactMap { $0.url?.host })
        self.shouldShowPinnedTabsInfo = !pinnedDomains.isEmpty

        updateItems(for: initialClearingOption)
    }

    var clearingOption = ClearingOption.allData {
        didSet {
            updateItems(for: clearingOption)
        }
    }

    let shouldShowPinnedTabsInfo: Bool

    private let fireViewModel: FireViewModel
    private weak var tabCollectionViewModel: TabCollectionViewModel?
    private let historyCoordinating: HistoryCoordinating
    private let fireproofDomains: FireproofDomains
    private let faviconManagement: FaviconManagement
    private let pinnedDomains: Set<String>

    @Published private(set) var selectable: [Item] = []
    @Published private(set) var fireproofed: [Item] = []
    @Published private(set) var selected: Set<Int> = Set() {
        didSet {
            updateAreOtherTabsInfluenced()
        }
    }

    let selectableSectionIndex = 0
    let fireproofedSectionIndex = 1

    // MARK: - Options

    private func updateItems(for clearingOption: ClearingOption) {

        func visitedDomains(basedOn clearingOption: ClearingOption) -> Set<String> {
            switch clearingOption {
            case .currentTab:
                guard let tab = tabCollectionViewModel?.selectedTabViewModel?.tab else {
                    assertionFailure("No tab selected")
                    return Set<String>()
                }

                return tab.localHistory
            case .currentWindow:
                return tabCollectionViewModel?.tabCollection.localHistory ?? Set<String>()
            case .allData:
                return historyCoordinating.history?.visitedDomains ?? Set<String>()
            }
        }

        let visitedDomains = visitedDomains(basedOn: clearingOption)

        let fireproofed = visitedDomains
            .filter { domain in
                fireproofDomains.isFireproof(fireproofDomain: domain)
            }
        let selectable = visitedDomains
            .subtracting(fireproofed)
            .subtracting(pinnedDomains.map { $0.dropWWW() })

        self.selectable = selectable
            .map { Item(domain: $0, favicon: faviconManagement.getCachedFavicon(for: $0, sizeCategory: .small)?.image) }
            .sorted { $0.domain < $1.domain }
        self.fireproofed = fireproofed
            .map { Item(domain: $0, favicon: faviconManagement.getCachedFavicon(for: $0, sizeCategory: .small)?.image) }
            .sorted { $0.domain < $1.domain }

        selectAll()
    }

    // MARK: - Selection

    var areAllSelected: Bool {
        Set(0..<selectable.count) == selected
    }

    private func selectAll() {
        self.selected = Set(0..<selectable.count)
    }

    func select(index: Int) {
        guard index < selectable.count, index >= 0 else {
            assertionFailure("Index out of range")
            return
        }
        selected.insert(index)
    }

    func deselect(index: Int) {
        guard index < selectable.count, index >= 0 else {
            assertionFailure("Index out of range")
            return
        }
        selected.remove(index)
    }

    private var selectedDomains: Set<String> {
        return Set<String>(selected.compactMap {
            guard let selectedDomain = selectable[safe: $0]?.domain else {
                assertionFailure("Wrong index")
                return nil
            }
            return selectedDomain
        })
    }

    // MARK: - Warning

    @Published private(set) var areOtherTabsInfluenced = false

    private func updateAreOtherTabsInfluenced() {
        let selectedTab = tabCollectionViewModel?.selectedTabViewModel?.tab
        let allTabs = WindowControllersManager.shared.mainWindowControllers.flatMap {
            $0.mainViewController.tabCollectionViewModel.tabCollection.tabs
        }
        let otherTabs = allTabs.filter({ $0 != selectedTab })

        let otherTabsLocalHistory = otherTabs.reduce(Set<String>()) { result, tab in
            return result.union(tab.localHistory)
        }

        areOtherTabsInfluenced = !otherTabsLocalHistory.isDisjoint(with: selectedDomains)
    }

    // MARK: - Burning

    func burn() {
        let timedPixel = TimedPixel(.burn())

        let implicitlyFireproofedDomains = pinnedDomains.filter({ !fireproofDomains.isFireproof(fireproofDomain: $0) })
        let completion: () -> Void = { [weak self] in
            implicitlyFireproofedDomains.forEach { self?.fireproofDomains.remove(domain: $0) }
            timedPixel.fire()
        }

        implicitlyFireproofedDomains.forEach { fireproofDomains.add(domain: $0, notify: false) }

        if clearingOption == .allData && areAllSelected {
            if let tabCollectionViewModel = tabCollectionViewModel {
                // Burn everything
                fireViewModel.fire.burnAll(tabCollectionViewModel: tabCollectionViewModel, completion: completion)
            }
        } else {
            // Burn selected domains
            fireViewModel.fire.burnDomains(selectedDomains, completion: completion)
        }
    }

}
