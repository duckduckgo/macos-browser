//
//  RecentlyClosedTabsCacheItem.swift
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

import Foundation

protocol RecentlyClosedCacheItem: AnyObject, RecentlyClosedCacheItemBurning {}

protocol RecentlyClosedCacheItemBurning {
    func burned(for domains: Set<String>) -> Self?
}

extension RecentlyClosedTab: RecentlyClosedCacheItemBurning {
    func burned(for domains: Set<String>) -> RecentlyClosedTab? {
        if contentContainsDomains(domains) {
            return nil
        }
        interactionData = nil
        return self
    }

    private func contentContainsDomains(_ domains: Set<String>) -> Bool {
        if let host = tabContent.url?.host, domains.contains(host) {
            return true
        } else {
            return false
        }
    }
}

extension RecentlyClosedWindow: RecentlyClosedCacheItemBurning {
    func burned(for domains: Set<String>) -> RecentlyClosedWindow? {
        tabs = tabs.compactMap { $0.burned(for: domains) }
        return tabs.isEmpty ? nil : self
    }
}

extension Array where Element == RecentlyClosedCacheItem {
    mutating func burn(for domains: Set<String>) {
        self = compactMap { $0.burned(for: domains) }
    }
}
