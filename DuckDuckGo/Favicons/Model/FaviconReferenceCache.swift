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

final class FaviconReferenceCache {

    private let storing: FaviconStoring

    // References to favicon URLs for whole domains
    private(set) var hostReferences = [String: FaviconHostReference]()

    // References to favicon URLs for special URLs
    private(set) var urlReferences = [URL: FaviconUrlReference]()

    private var cancellables = Set<AnyCancellable>()

    init(faviconStoring: FaviconStoring) {
        storing = faviconStoring
    }

    private(set) var loaded = false

    func loadReferences(completionHandler: ((Error?) -> Void)? = nil) {
        storing.loadFaviconReferences()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("References loaded successfully", log: .favicons)
                    NotificationCenter.default.post(name: .faviconCacheUpdated, object: nil)
                    completionHandler?(nil)
                case .failure(let error):
                    os_log("Loading of references failed: %s", log: .favicons, type: .error, error.localizedDescription)
                    completionHandler?(error)
                }
            }, receiveValue: { [weak self] (hostReferences, urlReferences) in
                hostReferences.forEach { reference in
                    self?.hostReferences[reference.host] = reference
                }
                urlReferences.forEach { reference in
                    self?.urlReferences[reference.documentUrl] = reference
                }
                self?.loaded = true
            })
            .store(in: &self.cancellables)
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
                    let hostCacheEntry = hostReferences[host] ?? (host.hasPrefix("www") ?
                                                                  hostReferences[host.droppingWwwPrefix()] : hostReferences["www.\(host)"]) {
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

        let hostCacheEntry = hostReferences[host] ?? (host.hasPrefix("www") ? hostReferences[host.droppingWwwPrefix()] : hostReferences["www.\(host)"])

        switch sizeCategory {
        case .small: return hostCacheEntry?.smallFaviconUrl ?? hostCacheEntry?.mediumFaviconUrl
        default: return hostCacheEntry?.mediumFaviconUrl
        }
    }

    // MARK: - Clean

    func cleanOldExcept(fireproofDomains: FireproofDomains,
                        bookmarkManager: BookmarkManager,
                        completion: (() -> Void)? = nil) {
        // Remove host references
        removeHostReferences(filter: { hostReference in
            let host = hostReference.host
            return hostReference.dateCreated < Date.monthAgo &&
                !fireproofDomains.isFireproof(fireproofDomain: host) &&
                !bookmarkManager.isHostInBookmarks(host: host)
        }) {
            // Remove URL references
            self.removeUrlReferences(filter: { urlReference in
                guard let host = urlReference.documentUrl.host else {
                    return false
                }
                return urlReference.dateCreated < Date.monthAgo &&
                !fireproofDomains.isFireproof(fireproofDomain: host) &&
                !bookmarkManager.isHostInBookmarks(host: host)
            }, completionHandler: completion)
        }
    }

    // MARK: - Burning

    func burnExcept(fireproofDomains: FireproofDomains,
                    bookmarkManager: BookmarkManager,
                    savedLogins: Set<String>,
                    completion: @escaping () -> Void) {

        func isHostApproved(host: String) -> Bool {
            return fireproofDomains.isFireproof(fireproofDomain: host) ||
                bookmarkManager.isHostInBookmarks(host: host) ||
                savedLogins.contains(host)
        }

        // Remove host references
        removeHostReferences(filter: { hostReference in
            let host = hostReference.host
            return !isHostApproved(host: host)
        }) {
            // Remove URL references
            self.removeUrlReferences(filter: { urlReference in
                guard let host = urlReference.documentUrl.host else {
                    return false
                }
                return !isHostApproved(host: host)
            }, completionHandler: completion)
        }
    }

    func burnDomains(_ baseDomains: Set<String>,
                     exceptBookmarks bookmarkManager: BookmarkManager,
                     exceptSavedLogins: Set<String>,
                     tld: TLD,
                     completion: @escaping () -> Void) {
        // Remove host references
        removeHostReferences(filter: { hostReference in
            let host = hostReference.host
            let baseDomain = tld.eTLDplus1(host) ?? ""
            return baseDomains.contains(baseDomain) && !bookmarkManager.isHostInBookmarks(host: host) && !exceptSavedLogins.contains(host)
        }) {
            // Remove URL references
            self.removeUrlReferences(filter: { urlReference in
                guard let host = urlReference.documentUrl.host else {
                    return false
                }
                return baseDomains.contains(host) && !bookmarkManager.isHostInBookmarks(host: host) && !exceptSavedLogins.contains(host)
            }, completionHandler: completion)
        }
    }

    // MARK: - Private

    private func insertToHostCache(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), host: String, documentUrl: URL) {
        // Remove existing
        if let oldReference = hostReferences[host] {
            removeHostReferencesFromStore([oldReference])
        }

        // Create and save new references
        let hostReference = FaviconHostReference(identifier: UUID(),
                                              smallFaviconUrl: faviconUrls.smallFaviconUrl,
                                              mediumFaviconUrl: faviconUrls.mediumFaviconUrl,
                                              host: host,
                                              documentUrl: documentUrl,
                                              dateCreated: Date())
        hostReferences[host] = hostReference

        storing.save(hostReference: hostReference)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Host reference saved successfully. host: %s", log: .favicons, hostReference.host)
                case .failure(let error):
                    os_log("Saving of host reference failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    private func insertToUrlCache(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), documentUrl: URL) {
        // Remove existing
        if let oldReference = urlReferences[documentUrl] {
            removeUrlReferencesFromStore([oldReference])
        }

        // Create and save new references
        let urlReference = FaviconUrlReference(identifier: UUID(),
                                             smallFaviconUrl: faviconUrls.smallFaviconUrl,
                                             mediumFaviconUrl: faviconUrls.mediumFaviconUrl,
                                             documentUrl: documentUrl,
                                             dateCreated: Date())

        urlReferences[documentUrl] = urlReference

        storing.save(urlReference: urlReference)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("URL reference saved successfully. document URL: %s", log: .favicons, urlReference.documentUrl.absoluteString)
                case .failure(let error):
                    os_log("Saving of URL reference failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    private func invalidateUrlCache(for host: String) {
        removeUrlReferences { urlReference in
            urlReference.documentUrl.host == host
        }
    }

    private func removeHostReferences(filter isRemoved: (FaviconHostReference) -> Bool, completionHandler: (() -> Void)? = nil) {
        let hostReferencesToRemove = hostReferences.values.filter(isRemoved)
        hostReferencesToRemove.forEach { hostReferences[$0.host] = nil }

        removeHostReferencesFromStore(hostReferencesToRemove, completionHandler: completionHandler)
    }

    private func removeHostReferencesFromStore(_ hostReferences: [FaviconHostReference], completionHandler: (() -> Void)? = nil) {
        guard !hostReferences.isEmpty else { completionHandler?(); return }

        storing.remove(hostReferences: hostReferences)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Host references removed successfully.", log: .favicons)
                case .failure(let error):
                    os_log("Removing of host references failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
                completionHandler?()
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    private func removeUrlReferences(filter isRemoved: (FaviconUrlReference) -> Bool, completionHandler: (() -> Void)? = nil) {
        let urlReferencesToRemove = urlReferences.values.filter(isRemoved)
        urlReferencesToRemove.forEach { urlReferences[$0.documentUrl] = nil }

        removeUrlReferencesFromStore(urlReferencesToRemove, completionHandler: completionHandler)
    }

    private func removeUrlReferencesFromStore(_ urlReferences: [FaviconUrlReference], completionHandler: (() -> Void)? = nil) {
        guard !urlReferences.isEmpty else { completionHandler?(); return }

        self.storing.remove(urlReferences: urlReferences)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("URL references removed successfully.", log: .favicons)
                case .failure(let error):
                    os_log("Removing of URL references failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
                completionHandler?()
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

}
