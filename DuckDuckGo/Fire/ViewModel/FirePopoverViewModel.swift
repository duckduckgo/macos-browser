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
        updateItems(for: initialClearingOption)
    }

    var clearingOption = ClearingOption.allData {
        didSet {
            updateItems(for: clearingOption)
        }
    }

    private let fireViewModel: FireViewModel
    private let tabCollectionViewModel: TabCollectionViewModel
    private let historyCoordinating: HistoryCoordinating
    private let fireproofDomains: FireproofDomains
    private let faviconManagement: FaviconManagement

    @Published private(set) var fireproofed: [Item] = []
    @Published private(set) var selectable: [Item] = []
    @Published private(set) var selected: Set<Int> = Set()

    // MARK: - Options

    private func updateItems(for clearingOption: ClearingOption) {

        func visitedDomains(basedOn clearingOption: ClearingOption) -> Set<String> {
            switch clearingOption {
            case .currentTab:
                guard let tab = tabCollectionViewModel.selectedTabViewModel?.tab else {
                    assertionFailure("No tab selected")
                    return Set<String>()
                }

                return tab.visitedDomains
            case .currentWindow:
                return tabCollectionViewModel.tabCollection.tabs.reduce(Set<String>()) { result, tab in
                    return result.union(tab.visitedDomains)
                }
            case .allData:
                return historyCoordinating.history?.reduce(Set<String>(), { result, historyEntry in
                    if let host = historyEntry.url.host {
                        return result.union([host])
                    } else {
                        return result
                    }
                }) ?? Set<String>()
            }
        }

        func dropWWW(domains: Set<String>) -> Set<String> {
            return Set(domains.map { $0.dropWWW() })
        }

        let visitedDomains = dropWWW(domains: visitedDomains(basedOn: clearingOption))

        let fireproofed = visitedDomains
            .filter { domain in
                fireproofDomains.isFireproof(fireproofDomain: domain)
            }
        let selectable = visitedDomains
            .subtracting(fireproofed)

        self.fireproofed = fireproofed
            .map { Item(domain: $0, favicon: faviconManagement.getCachedFavicon(for: $0, mustBeFromUserScript: false)) }
            .sorted { $0.domain < $1.domain }
        self.selectable = selectable
            .map { Item(domain: $0, favicon: faviconManagement.getCachedFavicon(for: $0, mustBeFromUserScript: false)) }
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

    // MARK: - Burning

    func burn() {
        let timedPixel = TimedPixel(.burn())
        if clearingOption == .allData && areAllSelected {
            // Burn everything
            fireViewModel.fire.burnAll(tabCollectionViewModel: tabCollectionViewModel) { timedPixel.fire() }
        } else {
            // Burn selected domains
            let selectedDomains = Set<String>(selected.compactMap {
                guard let selectedDomain = selectable[safe: $0]?.domain else {
                    assertionFailure("Wrong index")
                    return nil
                }
                return selectedDomain
            })

            fireViewModel.fire.burnDomains(selectedDomains) { timedPixel.fire() }
        }
    }

}
