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
import Common

@MainActor
final class FirePopoverViewModel {

    enum ClearingOption: Int, CaseIterable {

        case currentSite
        case currentTab
        case currentWindow
        case allData

        var string: String {
            switch self {
            case .currentSite: return UserText.currentSite
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
         initialClearingOption: ClearingOption = .allData,
         tld: TLD) {

        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel
        self.historyCoordinating = historyCoordinating
        self.fireproofDomains = fireproofDomains
        self.faviconManagement = faviconManagement
        self.clearingOption = initialClearingOption
        self.tld = tld

        updateAvailableClearingOptions()
        updateItems(for: initialClearingOption)
    }

    var clearingOption = ClearingOption.allData {
        didSet {
            updateItems(for: clearingOption)
        }
    }

    private(set) var shouldShowPinnedTabsInfo: Bool = false

    private let fireViewModel: FireViewModel
    private weak var tabCollectionViewModel: TabCollectionViewModel?
    private let historyCoordinating: HistoryCoordinating
    private let fireproofDomains: FireproofDomains
    private let faviconManagement: FaviconManagement
    private let tld: TLD

    private(set) var availableClearingOptions = ClearingOption.allCases
    private(set) var hasOnlySingleFireproofDomain: Bool = false
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

    private func updateAvailableClearingOptions() {
        guard let viewModel = tabCollectionViewModel else {
            assertionFailure("FirePopoverViewModel: TabCollectionViewModel is not present")
            return
        }

        var options: [ClearingOption] = []

        let urlTabsCount = viewModel.tabCollection.tabs.filter(\.content.isUrl).count + (viewModel.pinnedTabsCollection?.tabs.count ?? 0)

        if urlTabsCount == 1, let currentTab = viewModel.selectedTabViewModel?.tab, currentTab.localHistory.count == 1 {
            options.append(.currentSite)
        } else {
            options.append(.currentTab)
            if urlTabsCount > 1 {
                options.append(.currentWindow)
            }
        }

        options.append(.allData)

        availableClearingOptions = options
    }

    private func updateItems(for clearingOption: ClearingOption) {

        func visitedDomains(basedOn clearingOption: ClearingOption) -> Set<String> {
            switch clearingOption {
            case .currentTab, .currentSite:
                guard let tab = tabCollectionViewModel?.selectedTabViewModel?.tab else {
                    assertionFailure("No tab selected")
                    return Set<String>()
                }

                return tab.localHistory
            case .currentWindow:
                guard let tabCollectionViewModel = tabCollectionViewModel else {
                    return []
                }

                return tabCollectionViewModel.localHistory
            case .allData:
                return historyCoordinating.history?.visitedDomains ?? Set<String>()
            }
        }

        let visitedDomains = visitedDomains(basedOn: clearingOption)
        let visitedRootDomains = Set(visitedDomains.compactMap { tld.eTLDplus1($0) })

        let fireproofed = visitedRootDomains
            .filter { domain in
                fireproofDomains.isFireproof(fireproofDomain: domain)
            }
        let selectable = visitedRootDomains
            .subtracting(fireproofed)

        if visitedRootDomains.count == 1, let domain = visitedRootDomains.first, fireproofed.contains(domain) {
            self.hasOnlySingleFireproofDomain = true
        } else {
            self.hasOnlySingleFireproofDomain = false
        }

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

    var hasPinnedTabs: Bool {
        guard let pinnedTabsManager = tabCollectionViewModel?.pinnedTabsManager else {
            return false
        }
        return pinnedTabsManager.tabCollection.tabs.isEmpty
    }

    private func updateAreOtherTabsInfluenced() {
        let selectedTab = tabCollectionViewModel?.selectedTabViewModel?.tab
        var allTabs = WindowControllersManager.shared.mainWindowControllers.flatMap {
            $0.mainViewController.tabCollectionViewModel.tabCollection.tabs
        }
        if let pinnedTabs = tabCollectionViewModel?.pinnedTabsManager?.tabCollection.tabs {
            allTabs.append(contentsOf: pinnedTabs)
        }
        let otherTabs = allTabs.filter({ $0 != selectedTab })

        let otherTabsLocalHistory = otherTabs.reduce(Set<String>()) { result, tab in
            return result.union(tab.localHistory)
        }

        areOtherTabsInfluenced = !otherTabsLocalHistory.isDisjoint(with: selectedDomains)
    }

    // MARK: - Burning

    func burn() {
        if clearingOption == .allData && areAllSelected {
            if let tabCollectionViewModel = tabCollectionViewModel {
                // Burn everything
                fireViewModel.fire.burnAll(tabCollectionViewModel: tabCollectionViewModel)
            }
        } else {
            // Burn selected domains
            fireViewModel.fire.burnDomains(selectedDomains)
        }
    }

}
