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
import os.log

final class FaviconReferenceCache {

    private let storing: FaviconStoring
    private let queue: DispatchQueue

    // References to favicon URLs for whole domains
    private var hostReferences = [String: FaviconHostReference]()

    // References to favicon URLs for special URLs
    private var urlReferences = [URL: FaviconUrlReference]()

    private var cancellables = Set<AnyCancellable>()

    init(faviconQueue: DispatchQueue, faviconStoring: FaviconStoring) {
        storing = faviconStoring
        queue = faviconQueue
    }

    private(set) var loaded = false

    func loadReferences(completionHandler: ((Error?) -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(queue))

        storing.loadFaviconReferences()
            .receive(on: self.queue, options: .init(flags: .barrier))
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("References loaded successfully", log: .favicons)
                    completionHandler?(nil)
                case .failure(let error):
                    os_log("Loading of references failed: %s", log: .favicons, type: .error, error.localizedDescription)
                    completionHandler?(error)
                }
            }, receiveValue: { [weak self] (hostReferences, urlReferences) in
                dispatchPrecondition(condition: .onQueue(self!.queue))
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
        dispatchPrecondition(condition: .onQueue(queue))
        guard loaded else { return }

        guard let host = documentUrl.host else {
            insertToUrlCache(faviconUrls: faviconUrls, documentUrl: documentUrl)
            return
        }

        if let cacheEntry = hostReferences[host] {
            // Host references already cached

            if cacheEntry.smallFaviconUrl == faviconUrls.smallFaviconUrl && cacheEntry.mediumFaviconUrl == faviconUrls.mediumFaviconUrl {
                // Equal
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
        dispatchPrecondition(condition: .onQueue(queue))

        if let urlCacheEntry = urlReferences[documentURL] {
            switch sizeCategory {
            case .small: return urlCacheEntry.smallFaviconUrl ?? urlCacheEntry.mediumFaviconUrl
            default: return urlCacheEntry.mediumFaviconUrl
            }
        } else if let host = documentURL.host,
                    let hostCacheEntry = hostReferences[host] ?? (host.hasPrefix("www") ?
                                                                  hostReferences[host.dropWWW()] : hostReferences["www.\(host)"]) {
            switch sizeCategory {
            case .small: return hostCacheEntry.smallFaviconUrl ?? hostCacheEntry.mediumFaviconUrl
            default: return hostCacheEntry.mediumFaviconUrl
            }
        }

        return nil
    }

    func getFaviconUrl(for host: String, sizeCategory: Favicon.SizeCategory) -> URL? {
        dispatchPrecondition(condition: .onQueue(queue))

        let hostCacheEntry = hostReferences[host] ?? (host.hasPrefix("www") ? hostReferences[host.dropWWW()] : hostReferences["www.\(host)"])

        switch sizeCategory {
        case .small: return hostCacheEntry?.smallFaviconUrl ?? hostCacheEntry?.mediumFaviconUrl
        default: return hostCacheEntry?.mediumFaviconUrl
        }
    }

    // MARK: - Burning

    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))

        // Remove host references
        let hostReferencesToBurn = hostReferences.values.filter { hostReference in
            let host = hostReference.host
            return !fireproofDomains.isFireproof(fireproofDomain: host)
        }

        remove(hostReferences: hostReferencesToBurn) {
            // Remove URL references
            let urlReferencesToBurn = self.urlReferences.values.filter { urlReference in
                guard let host = urlReference.documentUrl.host else {
                    return false
                }
                return !fireproofDomains.isFireproof(fireproofDomain: host)
            }
            self.remove(urlReferences: urlReferencesToBurn, completionHandler: completion)
        }
    }

    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))

        // Remove host references
        let hostReferencesToBurn = hostReferences.values.filter { hostReference in
            return domains.contains(hostReference.host)
        }

        remove(hostReferences: hostReferencesToBurn) {
            // Remove URL references
            let urlReferencesToBurn = self.urlReferences.values.filter { urlReference in
                guard let host = urlReference.documentUrl.host else {
                    return false
                }
                return domains.contains(host)
            }
            self.remove(urlReferences: urlReferencesToBurn, completionHandler: completion)
        }
    }

    // MARK: - Private

    private func insertToHostCache(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), host: String, documentUrl: URL) {
        // Remove existing
        if let oldReference = hostReferences[host] {
            remove(hostReferences: [oldReference])
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
            .receive(on: self.queue, options: .init(flags: .barrier))
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
            remove(urlReferences: [oldReference])
        }

        // Create and save new references
        let urlReference = FaviconUrlReference(identifier: UUID(),
                                             smallFaviconUrl: faviconUrls.smallFaviconUrl,
                                             mediumFaviconUrl: faviconUrls.mediumFaviconUrl,
                                             documentUrl: documentUrl,
                                             dateCreated: Date())

        urlReferences[documentUrl] = urlReference

        storing.save(urlReference: urlReference)
            .receive(on: self.queue, options: .init(flags: .barrier))
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
        let toInvalidateReferences = urlReferences.values.filter { urlReference in
            urlReference.documentUrl.host == host
        }

        toInvalidateReferences.forEach { urlReferences[$0.documentUrl] = nil }
        remove(urlReferences: toInvalidateReferences)
    }

    private func remove(hostReferences: [FaviconHostReference], completionHandler: (() -> Void)? = nil) {
        storing.remove(hostReferences: hostReferences)
            .receive(on: self.queue, options: .init(flags: .barrier))
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Host references burned successfully.", log: .favicons)
                case .failure(let error):
                    os_log("Burning of host references failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
                completionHandler?()
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    private func remove(urlReferences: [FaviconUrlReference], completionHandler: (() -> Void)? = nil) {
        self.storing.remove(urlReferences: urlReferences)
            .receive(on: self.queue, options: .init(flags: .barrier))
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("URL references burned successfully.", log: .favicons)
                case .failure(let error):
                    os_log("Burning of URL references failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
                completionHandler?()
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

}
