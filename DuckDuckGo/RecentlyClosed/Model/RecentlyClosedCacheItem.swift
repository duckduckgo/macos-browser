//
//  RecentlyClosedCacheItem.swift
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
import Common

protocol RecentlyClosedCacheItem: AnyObject, RecentlyClosedCacheItemBurning {}

protocol RecentlyClosedCacheItemBurning {
    func burned(for baseDomains: Set<String>, tld: TLD) -> Self?
}

extension RecentlyClosedTab: RecentlyClosedCacheItemBurning {
    func burned(for baseDomains: Set<String>, tld: TLD) -> RecentlyClosedTab? {
        if contentContainsDomains(baseDomains, tld: tld) {
            return nil
        }
        interactionData = nil
        return self
    }

    private func contentContainsDomains(_ baseDomains: Set<String>, tld: TLD) -> Bool {
        if let host = tabContent.urlForWebView?.host, let baseDomain = tld.eTLDplus1(host), baseDomains.contains(baseDomain) {
            return true
        } else {
            return false
        }
    }
}

extension RecentlyClosedWindow: RecentlyClosedCacheItemBurning {
    func burned(for baseDomains: Set<String>, tld: TLD) -> RecentlyClosedWindow? {
        tabs = tabs.compactMap { $0.burned(for: baseDomains, tld: tld) }
        return tabs.isEmpty ? nil : self
    }
}

extension Array where Element == RecentlyClosedCacheItem {
    mutating func burn(for baseDomains: Set<String>, tld: TLD) {
        self = compactMap { $0.burned(for: baseDomains, tld: tld) }
    }
}
