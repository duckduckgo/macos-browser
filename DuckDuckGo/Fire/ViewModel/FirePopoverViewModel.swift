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
import History
import PixelKit

@MainActor
final class FirePopoverViewModel {

    enum ClearingOption: Int, CaseIterable {

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
         initialClearingOption: ClearingOption = .allData,
         tld: TLD,
         contextualOnboardingStateMachine: ContextualOnboardingStateUpdater) {

        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel
        self.historyCoordinating = historyCoordinating
        self.fireproofDomains = fireproofDomains
        self.faviconManagement = faviconManagement
        self.clearingOption = initialClearingOption
        self.tld = tld
        self.contextualOnboardingStateMachine = contextualOnboardingStateMachine
    }

    var clearingOption = ClearingOption.allData {
        didSet {
            updateItems(for: clearingOption)
        }
    }

    private(set) var shouldShowPinnedTabsInfo: Bool = false

    private let fireViewModel: FireViewModel
    private(set) weak var tabCollectionViewModel: TabCollectionViewModel?
    private let historyCoordinating: HistoryCoordinating
    private let fireproofDomains: FireproofDomains
    private let faviconManagement: FaviconManagement
    private let tld: TLD
    private let contextualOnboardingStateMachine: ContextualOnboardingStateUpdater

    private(set) var hasOnlySingleFireproofDomain: Bool = false
    @Published private(set) var selectable: [Item] = []
    @Published private(set) var fireproofed: [Item] = []
    @Published private(set) var selected: Set<Int> = Set()

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

                return tab.localHistoryDomains
            case .currentWindow:
                guard let tabCollectionViewModel = tabCollectionViewModel else {
                    return []
                }

                return tabCollectionViewModel.localHistoryDomains
            case .allData:
                return (historyCoordinating.history?.visitedDomains(tld: tld) ?? Set<String>())
                    .union(tabCollectionViewModel?.localHistoryDomains ?? Set<String>())
            }
        }

        let visitedDomains = visitedDomains(basedOn: clearingOption)
        let visitedETLDPlus1Domains = Set(visitedDomains.compactMap { tld.eTLDplus1($0) })

        let fireproofed = visitedETLDPlus1Domains
            .filter { domain in
                fireproofDomains.isFireproof(fireproofDomain: domain)
            }
        let selectable = visitedETLDPlus1Domains
            .subtracting(fireproofed)

        if visitedETLDPlus1Domains.count == 1, let domain = visitedETLDPlus1Domains.first, fireproofed.contains(domain) {
            self.hasOnlySingleFireproofDomain = true
        } else {
            self.hasOnlySingleFireproofDomain = false
        }

        self.selectable = selectable
            .map { Item(domain: $0, favicon: faviconManagement.getCachedFavicon(forDomainOrAnySubdomain: $0, sizeCategory: .small)?.image) }
            .sorted { $0.domain < $1.domain }
        self.fireproofed = fireproofed
            .map { Item(domain: $0, favicon: faviconManagement.getCachedFavicon(forDomainOrAnySubdomain: $0, sizeCategory: .small)?.image) }
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

    func refreshItems() {
        updateItems(for: clearingOption)
    }

    // MARK: - Warning

    var hasPinnedTabs: Bool {
        guard let pinnedTabsManager = tabCollectionViewModel?.pinnedTabsManager else {
            return false
        }
        return pinnedTabsManager.tabCollection.tabs.isEmpty
    }

    // MARK: - Burning

    func burn() {
        contextualOnboardingStateMachine.fireButtonUsed()
        PixelKit.fire(GeneralPixel.fireButtonFirstBurn, frequency: .legacyDaily)

        switch (clearingOption, areAllSelected) {
        case (.currentTab, _):
            guard let tabCollectionViewModel = tabCollectionViewModel,
                  let tabViewModel = tabCollectionViewModel.selectedTabViewModel else {
                assertionFailure("No tab selected")
                return
            }
            PixelKit.fire(GeneralPixel.fireButton(option: .tab))
            let burningEntity = Fire.BurningEntity.tab(tabViewModel: tabViewModel,
                                                       selectedDomains: selectedDomains,
                                                       parentTabCollectionViewModel: tabCollectionViewModel)
            fireViewModel.fire.burnEntity(entity: burningEntity)
        case (.currentWindow, _):
            guard let tabCollectionViewModel = tabCollectionViewModel else {
                assertionFailure("FirePopoverViewModel: TabCollectionViewModel is not present")
                return
            }
            PixelKit.fire(GeneralPixel.fireButton(option: .window))
            let burningEntity = Fire.BurningEntity.window(tabCollectionViewModel: tabCollectionViewModel,
                                                          selectedDomains: selectedDomains)
            fireViewModel.fire.burnEntity(entity: burningEntity)

        case (.allData, true):
            PixelKit.fire(GeneralPixel.fireButton(option: .allSites))
            fireViewModel.fire.burnAll()

        case (.allData, false):
            PixelKit.fire(GeneralPixel.fireButton(option: .allSites))
            fireViewModel.fire.burnEntity(entity: .allWindows(mainWindowControllers: WindowControllersManager.shared.mainWindowControllers,
                                                              selectedDomains: selectedDomains))
        }
    }

}

extension BrowsingHistory {

    func visitedDomains(tld: TLD) -> Set<String> {
        return reduce(Set<String>(), { result, historyEntry in
            if let host = historyEntry.url.host, let eTLDPlus1Domain = tld.eTLDplus1(host) {
                return result.union([eTLDPlus1Domain])
            } else {
                return result
            }
        })
    }

}
