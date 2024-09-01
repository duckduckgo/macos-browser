//
//  FaviconReferenceCache.swift
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
final class FaviconReferenceCache {

    private let storing: FaviconStoring

    // References to favicon URLs for whole domains
    private(set) var hostReferences = [String: FaviconHostReference]()

    // References to favicon URLs for special URLs
    private(set) var urlReferences = [URL: FaviconUrlReference]()

    init(faviconStoring: FaviconStoring) {
        storing = faviconStoring
    }

    private(set) var loaded = false

    nonisolated func loadReferences(completionHandler: (@MainActor (Error?) -> Void)? = nil) {
        Task {
            do {
                try await self.load()
                await completionHandler?(nil)
            } catch {
                await completionHandler?(error)
            }
        }
    }

    nonisolated func load() async throws {
        do {
            let (hostReferences, urlReferences) = try await storing.loadFaviconReferences()

            await Task { @MainActor in
                for reference in hostReferences {
                    self.hostReferences[reference.host] = reference
                }
                for reference in urlReferences {
                    self.urlReferences[reference.documentUrl] = reference
                }
                loaded = true

                Logger.favicons.debug("References loaded successfully")

                NotificationCenter.default.post(name: .faviconCacheUpdated, object: nil)
            }.value
        } catch {
            Logger.favicons.error("Loading of references failed: \(error.localizedDescription)")
            throw error
        }
    }

    func insert(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), documentUrl: URL) {
        guard loaded else { return }

        guard let host = documentUrl.host else {
            insertToUrlCache(faviconUrls: faviconUrls, documentUrl: documentUrl)
            return
        }

        if let cacheEntry = hostReferences[host] {
            // Host references already cached

            if cacheEntry.smallFaviconUrl == faviconUrls.smallFaviconUrl && cacheEntry.mediumFaviconUrl == faviconUrls.mediumFaviconUrl {
                // Equal

                // There is a possibility of old cache entry in urlReferences
                if urlReferences[documentUrl] != nil {
                    invalidateUrlCache(for: host)
                }
                return
            }

            if cacheEntry.documentUrl == documentUrl {
                // Favicon was updated

                // Exceptions may contain updated favicon if user visited a different documentUrl sooner
                invalidateUrlCache(for: host)
                insertToHostCache(faviconUrls: (faviconUrls.smallFaviconUrl, faviconUrls.mediumFaviconUrl), host: host, documentUrl: documentUrl)
                return
            } else {
                // Exception
                insertToUrlCache(faviconUrls: (faviconUrls.smallFaviconUrl, faviconUrls.mediumFaviconUrl), documentUrl: documentUrl)

                return
            }
        } else {
            // Not cached. Add to cache
            insertToHostCache(faviconUrls: (faviconUrls.smallFaviconUrl, faviconUrls.mediumFaviconUrl), host: host, documentUrl: documentUrl)

            return
        }
    }

    func getFaviconUrl(for documentURL: URL, sizeCategory: Favicon.SizeCategory) -> URL? {
        guard loaded else {
            return nil
        }

        if let urlCacheEntry = urlReferences[documentURL] {
            switch sizeCategory {
            case .small: return urlCacheEntry.smallFaviconUrl ?? urlCacheEntry.mediumFaviconUrl
            default: return urlCacheEntry.mediumFaviconUrl
            }
        } else if let host = documentURL.host,
                    let hostCacheEntry = hostReferences[host] {
            switch sizeCategory {
            case .small: return hostCacheEntry.smallFaviconUrl ?? hostCacheEntry.mediumFaviconUrl
            default: return hostCacheEntry.mediumFaviconUrl
            }
        }

        return nil
    }

    func getFaviconUrl(for host: String, sizeCategory: Favicon.SizeCategory) -> URL? {
        guard loaded else {
            return nil
        }

        let hostCacheEntry = hostReferences[host]

        switch sizeCategory {
        case .small: return hostCacheEntry?.smallFaviconUrl ?? hostCacheEntry?.mediumFaviconUrl
        default: return hostCacheEntry?.mediumFaviconUrl
        }
    }

    // MARK: - Clean

    nonisolated func cleanOldExcept(fireproofDomains: FireproofDomains,
                                    bookmarkManager: BookmarkManager,
                                    completion: (@MainActor (()) -> Void)? = nil) {
        Task {
            await self.cleanOld(except: fireproofDomains, bookmarkManager: bookmarkManager)
            await completion?(())
        }
    }

    func cleanOld(except fireproofDomains: FireproofDomains, bookmarkManager: BookmarkManager) async {
        let bookmarkedHosts = bookmarkManager.allHosts()
        // Remove host references
        await removeHostReferences(filter: { hostReference in
            let host = hostReference.host
            return hostReference.dateCreated < Date.monthAgo &&
                !fireproofDomains.isFireproof(fireproofDomain: host) &&
                !bookmarkedHosts.contains(host)
        }).value
        // Remove URL references
        await removeUrlReferences(filter: { urlReference in
            guard let host = urlReference.documentUrl.host else {
                return false
            }
            return urlReference.dateCreated < Date.monthAgo &&
            !fireproofDomains.isFireproof(fireproofDomain: host) &&
            !bookmarkedHosts.contains(host)
        }).value
    }

    // MARK: - Burning

    nonisolated func burnExcept(fireproofDomains: FireproofDomains,
                                bookmarkManager: BookmarkManager,
                                savedLogins: Set<String>,
                                completion: @escaping @MainActor () -> Void) {
        Task {
            await self.burn(except: fireproofDomains, bookmarkManager: bookmarkManager, savedLogins: savedLogins)
            await completion()
        }
    }

    func burn(except fireproofDomains: FireproofDomains, bookmarkManager: BookmarkManager, savedLogins: Set<String>) async {
        let bookmarkedHosts = bookmarkManager.allHosts()
        func isHostApproved(host: String) -> Bool {
            return fireproofDomains.isFireproof(fireproofDomain: host) ||
                bookmarkedHosts.contains(host) ||
                savedLogins.contains(host)
        }

        // Remove host references
        await removeHostReferences(filter: { hostReference in
            let host = hostReference.host
            return !isHostApproved(host: host)
        }).value
        // Remove URL references
        await removeUrlReferences(filter: { urlReference in
            guard let host = urlReference.documentUrl.host else {
                return false
            }
            return !isHostApproved(host: host)
        }).value
    }

    nonisolated func burnDomains(_ baseDomains: Set<String>,
                                 exceptBookmarks bookmarkManager: BookmarkManager,
                                 exceptSavedLogins logins: Set<String>,
                                 exceptHistoryDomains history: Set<String>,
                                 tld: TLD,
                                 completion: @escaping @MainActor () -> Void) {
        Task {
            await self.burnDomains(baseDomains, exceptBookmarks: bookmarkManager, exceptSavedLogins: logins, exceptHistoryDomains: history, tld: tld)
            await completion()
        }
    }

    func burnDomains(_ baseDomains: Set<String>,
                     exceptBookmarks bookmarkManager: BookmarkManager,
                     exceptSavedLogins logins: Set<String>,
                     exceptHistoryDomains history: Set<String>,
                     tld: TLD) async {
        // Remove host references
        let bookmarkedHosts = bookmarkManager.allHosts()
        await removeHostReferences(filter: { hostReference in
            let host = hostReference.host
            let baseDomain = tld.eTLDplus1(host) ?? ""
            return baseDomains.contains(baseDomain) && !bookmarkedHosts.contains(host) && !logins.contains(host) && !history.contains(host)
        }).value
        // Remove URL references
        await removeUrlReferences(filter: { urlReference in
            guard let host = urlReference.documentUrl.host else {
                return false
            }
            return baseDomains.contains(host) && !bookmarkedHosts.contains(host) && !logins.contains(host) && !history.contains(host)
        }).value
    }

    // MARK: - Private

    private func insertToHostCache(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), host: String, documentUrl: URL) {
        // Remove existing
        if let oldReference = hostReferences[host] {
            Task {
                await self.removeHostReferencesFromStore([oldReference])
            }
        }

        // Create and save new references
        let hostReference = FaviconHostReference(identifier: UUID(),
                                              smallFaviconUrl: faviconUrls.smallFaviconUrl,
                                              mediumFaviconUrl: faviconUrls.mediumFaviconUrl,
                                              host: host,
                                              documentUrl: documentUrl,
                                              dateCreated: Date())
        hostReferences[host] = hostReference

        Task {
            do {
                try await self.storing.save(hostReference: hostReference)
                Logger.favicons.debug("Host reference saved successfully. host: \(hostReference.host)")
            } catch {
                Logger.favicons.error("Saving of host reference failed: \(error.localizedDescription)")
            }
        }
    }

    private func insertToUrlCache(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), documentUrl: URL) {
        // Remove existing
        if let oldReference = urlReferences[documentUrl] {
            Task.detached {
                await self.removeUrlReferencesFromStore([oldReference])
            }
        }

        // Create and save new references
        let urlReference = FaviconUrlReference(identifier: UUID(),
                                             smallFaviconUrl: faviconUrls.smallFaviconUrl,
                                             mediumFaviconUrl: faviconUrls.mediumFaviconUrl,
                                             documentUrl: documentUrl,
                                             dateCreated: Date())

        urlReferences[documentUrl] = urlReference

        Task.detached {
            do {
                try await self.storing.save(urlReference: urlReference)
                Logger.favicons.debug("URL reference saved successfully. document URL: \(urlReference.documentUrl.absoluteString)")
            } catch {
                Logger.favicons.error("Saving of URL reference failed: \(error.localizedDescription)")
            }
        }
    }

    private func invalidateUrlCache(for host: String) {
        _=self.removeUrlReferences { urlReference in
            urlReference.documentUrl.host == host
        }
    }

    private func removeHostReferences(filter isRemoved: (FaviconHostReference) -> Bool) -> Task<Void, Never> {
        let hostReferencesToRemove = hostReferences.values.filter(isRemoved)
        hostReferencesToRemove.forEach { hostReferences[$0.host] = nil }

        return Task.detached {
            await self.removeHostReferencesFromStore(hostReferencesToRemove)
        }
    }

    private nonisolated func removeHostReferencesFromStore(_ hostReferences: [FaviconHostReference]) async {
        guard !hostReferences.isEmpty else { return }

        do {
            try await storing.remove(hostReferences: hostReferences)
            Logger.favicons.debug("Host references removed successfully.")
        } catch {
            Logger.favicons.error("Removing of host references failed: \(error.localizedDescription)")
        }
    }

    private func removeUrlReferences(filter isRemoved: (FaviconUrlReference) -> Bool) -> Task<Void, Never> {
        let urlReferencesToRemove = urlReferences.values.filter(isRemoved)
        urlReferencesToRemove.forEach { urlReferences[$0.documentUrl] = nil }

        return Task.detached {
            await self.removeUrlReferencesFromStore(urlReferencesToRemove)
        }
    }

    private nonisolated func removeUrlReferencesFromStore(_ urlReferences: [FaviconUrlReference]) async {
        guard !urlReferences.isEmpty else { return }

        do {
            try await storing.remove(urlReferences: urlReferences)
            Logger.favicons.debug("URL references removed successfully.")
        } catch {
            Logger.favicons.error("Removing of URL references failed: \(error.localizedDescription)")
        }
    }

}
