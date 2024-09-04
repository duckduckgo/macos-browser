//
//  FaviconImageCache.swift
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
import Combine
import Common
import BrowserServicesKit
import os.log

@MainActor
final class FaviconImageCache {

    private let storing: FaviconStoring

    private var entries = [URL: Favicon]()

    init(faviconStoring: FaviconStoring) {
        storing = faviconStoring
    }

    private(set) var loaded = false

    nonisolated func loadFavicons(completionHandler: (@MainActor (Error?) -> Void)? = nil) {
        Task {
            do {
                try await self.load()
                await completionHandler?(nil)
            } catch {
                await completionHandler?(error)
            }
        }
    }

    func load() async throws {
        let favicons: [Favicon]
        do {
            favicons = try await storing.loadFavicons()
            Logger.favicons.debug("Favicons loaded successfully")
        } catch {
            Logger.favicons.error("Loading of favicons failed: \(error.localizedDescription)")
            throw error
        }

        for favicon in favicons {
            entries[favicon.url] = favicon
        }
        loaded = true
    }

    func insert(_ favicons: [Favicon]) {
        guard loaded else { return }

        // Remove existing favicon with the same URL
        let oldFavicons = favicons.compactMap { entries[$0.url] }

        // Save the new ones
        for favicon in favicons {
            entries[favicon.url] = favicon
        }

        Task {
            do {
                await removeFaviconsFromStore(oldFavicons)
                try await storing.save(favicons)
                Logger.favicons.debug("Favicon saved successfully. URL: \(favicons.map(\.url.absoluteString).description)")
                await MainActor.run {
                    NotificationCenter.default.post(name: .faviconCacheUpdated, object: nil)
                }
            } catch {
                Logger.favicons.error("Saving of favicon failed: \(error.localizedDescription)")
            }
        }
    }

    func get(faviconUrl: URL) -> Favicon? {
        guard loaded else { return nil }

        return entries[faviconUrl]
    }

    func getFavicons(with urls: some Sequence<URL>) -> [Favicon]? {
        guard loaded else { return nil }

        return urls.compactMap { faviconUrl in entries[faviconUrl] }
    }

    // MARK: - Clean

    nonisolated func cleanOldExcept(fireproofDomains: FireproofDomains,
                                    bookmarkManager: BookmarkManager,
                                    completion: @escaping @MainActor () -> Void) {
        let bookmarkedHosts = bookmarkManager.allHosts()
        Task {
            await self.removeFavicons(filter: { favicon in
                guard let host = favicon.documentUrl.host else {
                    return false
                }
                return favicon.dateCreated < Date.monthAgo &&
                !fireproofDomains.isFireproof(fireproofDomain: host) &&
                !bookmarkedHosts.contains(host)
            })
            await completion()
        }
    }

    // MARK: - Burning

    nonisolated func burnExcept(fireproofDomains: FireproofDomains,
                                bookmarkManager: BookmarkManager,
                                savedLogins: Set<String>,
                                completion: @escaping @MainActor () -> Void) {
        let bookmarkedHosts = bookmarkManager.allHosts()
        Task {
            await self.removeFavicons(filter: { favicon in
                guard let host = favicon.documentUrl.host else {
                    return false
                }
                return !(fireproofDomains.isFireproof(fireproofDomain: host) ||
                         bookmarkedHosts.contains(host) ||
                         savedLogins.contains(host)
                )
            })
            await completion()
        }
    }

    nonisolated func burnDomains(_ baseDomains: Set<String>,
                                 exceptBookmarks bookmarkManager: BookmarkManager,
                                 exceptSavedLogins logins: Set<String>,
                                 exceptHistoryDomains history: Set<String>,
                                 tld: TLD,
                                 completion: @escaping @MainActor () -> Void) {
        let bookmarkedHosts = bookmarkManager.allHosts()
        Task {
            await self.removeFavicons(filter: { favicon in
                guard let host = favicon.documentUrl.host, let baseDomain = tld.eTLDplus1(host) else { return false }
                return baseDomains.contains(baseDomain)
                    && !bookmarkedHosts.contains(host)
                    && !logins.contains(host)
                    && !history.contains(host)
            })
            await completion()
        }
    }

    // MARK: - Private

    private func removeFavicons(filter isRemoved: (Favicon) -> Bool) async {
        let faviconsToRemove = entries.values.filter(isRemoved)
        faviconsToRemove.forEach { entries[$0.url] = nil }

        await removeFaviconsFromStore(faviconsToRemove)
    }

    private nonisolated func removeFaviconsFromStore(_ favicons: [Favicon]) async {
        guard !favicons.isEmpty else { return }

        do {
            try await storing.removeFavicons(favicons)
            Logger.favicons.debug("Favicons removed successfully.")
        } catch {
            Logger.favicons.error("Removing of favicons failed: \(error.localizedDescription)")
        }
    }

}
