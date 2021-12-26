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

//TODO: Invalidate host entries (plus clean url entries for the host)

final class FaviconReferenceCache {

    private let storing: FaviconStoring
    private let queue: DispatchQueue

    private var hostReferences = [String: FaviconHostReference]()
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
                    os_log("Favicon references loaded successfully", log: .favicons)
                    completionHandler?(nil)
                case .failure(let error):
                    os_log("Loading of favicon references failed: %s", log: .favicons, type: .error, error.localizedDescription)
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
            // Already cached

            if cacheEntry.smallFaviconUrl == faviconUrls.smallFaviconUrl && cacheEntry.mediumFaviconUrl == faviconUrls.mediumFaviconUrl {
                // Equal
                return
            }

            if cacheEntry.documentUrl == documentUrl {
                // Favicon was updated
                insertToHostCache(faviconUrls: (faviconUrls.smallFaviconUrl, faviconUrls.mediumFaviconUrl), host: host, documentUrl: documentUrl)
                //TODO: Invalidate URL cache with this host

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

    private func insertToHostCache(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), host: String, documentUrl: URL) {
        //TODO: duplicates!?
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
                    os_log("Favicon host reference saved successfully. host: %s", log: .favicons, hostReference.host)
                case .failure(let error):
                    os_log("Saving of favicon reference failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    private func insertToUrlCache(faviconUrls: (smallFaviconUrl: URL?, mediumFaviconUrl: URL?), documentUrl: URL) {
        //TODO: duplicates!?
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
                    os_log("Favicon url reference saved successfully. document url: %s", log: .favicons, urlReference.documentUrl.absoluteString)
                case .failure(let error):
                    os_log("Saving of favicon reference failed: %s", log: .favicons, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
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

    // MARK: Burning

    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        //TODO: Burn
    }

    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void) {
        //TODO: Burn
    }

}
