//
//  FireDomainList.swift
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

import Foundation
import BrowserServicesKit

struct FireDomainList {

    struct Item {
        var domain: String
        var favicon: NSImage?
    }

    static var empty: FireDomainList {
        return FireDomainList()
    }

    fileprivate init() {
        fireproofed = []
        selectable = []
    }

    init(tab: Tab,
         fireproofDomains: FireproofDomains = FireproofDomains.shared,
         faviconService: FaviconService = LocalFaviconService.shared) {
        self.init(visitedDomains: tab.visitedDomains, fireproofDomains: fireproofDomains, faviconService: faviconService)
    }

    init(tabCollection: TabCollection,
         fireproofDomains: FireproofDomains = FireproofDomains.shared,
         faviconService: FaviconService = LocalFaviconService.shared) {
        let visitedDomains = tabCollection.tabs.reduce(Set<String>()) { result, tab in
            return result.union(tab.visitedDomains)
        }
        self.init(visitedDomains: visitedDomains, fireproofDomains: fireproofDomains, faviconService: faviconService)
    }

    init(historyCoordinating: HistoryCoordinating,
         fireproofDomains: FireproofDomains = FireproofDomains.shared,
         faviconService: FaviconService = LocalFaviconService.shared) {
        let visitedDomains = historyCoordinating.history?.reduce(Set<String>(), { result, historyEntry in
            if let host = historyEntry.url.host {
                return result.union([host])
            } else {
                return result
            }
        }) ?? Set<String>()
        self.init(visitedDomains: visitedDomains, fireproofDomains: fireproofDomains, faviconService: faviconService)
    }
    
    init(visitedDomains: Set<String>,
         fireproofDomains: FireproofDomains = FireproofDomains.shared,
         faviconService: FaviconService = LocalFaviconService.shared) {
        let (fireproofed, selectable) = Self.fireproofedAndSelectableDomains(from: visitedDomains, fireproofDomains: fireproofDomains)

        self.fireproofed = fireproofed
            .map { Item(domain: $0, favicon: faviconService.getCachedFavicon(for: $0, mustBeFromUserScript: false)) }
            .sorted { $0.domain < $1.domain }
        self.selectable = selectable
            .map { Item(domain: $0, favicon: faviconService.getCachedFavicon(for: $0, mustBeFromUserScript: false)) }
            .sorted { $0.domain < $1.domain }
    }

    var fireproofed: [Item]
    var selectable: [Item]

}

extension FireDomainList {

    private static func fireproofedAndSelectableDomains(from visitedDomains: Set<String>,
                                                        fireproofDomains: FireproofDomains) -> (fireproofed: Set<String>, selectable: Set<String>) {
        let fireproofed = visitedDomains
            .filter { domain in
                fireproofDomains.isFireproof(fireproofDomain: domain)
            }
        let selectable = visitedDomains
            .subtracting(fireproofed)
        return (fireproofed, selectable)
    }

}
