//
//  FaviconManager.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import Combine

// Update tech design
// Product feedback request
// Design Review
// Privacy triage

// TODOs
// Synchronous favicon getting?
// Burning
// Selection of favicon links in FaviconSelector
// Invalidating or better - redownloading if cache entry is old

protocol FaviconManagement {

    func fetchFavicons(_ faviconLinks: [FaviconUserScript.FaviconLink],
                       documentUrl: URL,
                       completion: @escaping (Favicon?, Error?) -> Void)
    func getCachedFavicon(for documentUrl: URL, sizeCategory: Favicon.SizeCategory) -> Favicon?
    func getCachedFavicon(for host: String, sizeCategory: Favicon.SizeCategory) -> Favicon?

    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void)
    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void)

}

final class FaviconManager: FaviconManagement {

    static let shared = FaviconManager()

    private let queue = DispatchQueue(label: "FaviconManager queue", attributes: .concurrent)
    private lazy var store: FaviconStoring = FaviconStore()

    private init() {
        queue.async {
            self.imageCache.loadFavicons { _ in
                self.referenceCache.loadReferences()
            }
        }
    }

    // MARK: - Fetching & Cache

    private lazy var imageCache = FaviconImageCache(faviconQueue: queue, faviconStoring: store)
    private lazy var referenceCache = FaviconReferenceCache(faviconQueue: queue, faviconStoring: store)

    func fetchFavicons(_ faviconLinks: [FaviconUserScript.FaviconLink],
                       documentUrl: URL,
                       completion: @escaping (Favicon?, Error?) -> Void) {

        func mainQueueCompletion(_ favicon: Favicon?, _ error: Error?) {
            DispatchQueue.main.async {
                completion(favicon, error)
            }
        }

        //TODO: Optimizations: If every favicon is cached, then completion

        queue.async { [weak self] in
            var faviconLinks = faviconLinks
            if let host = documentUrl.host {
                let faviconIcoLink = FaviconUserScript.FaviconLink(href: "\(URL.NavigationalScheme.https.separated())\(host)/favicon.ico",
                                                                   rel: "favicon.ico")
                faviconLinks.append(faviconIcoLink)
            }

            faviconLinks = FaviconSelector.filterUnnecessaryFaviconLink(faviconLinks: faviconLinks)

            // Load favicons if needed
            let favicons: [Favicon] = faviconLinks
                .compactMap { faviconLink -> Favicon? in
                    guard let faviconUrl = URL(string: faviconLink.href) else {
                        return nil
                    }

                    //TODO: guard not older than one week!
                    if let favicon = self?.imageCache.get(faviconUrl: faviconUrl) {
                        return favicon
                    }

                    if let loadedImage = NSImage(contentsOf: faviconUrl), loadedImage.isValid {
                        let newFavicon = Favicon(identifier: UUID(),
                                                 url: faviconUrl,
                                                 image: loadedImage,
                                                 relationString: faviconLink.rel,
                                                 dateCreated: Date())
                        self?.imageCache.insert(newFavicon)
                        return newFavicon
                    }

                    return nil
                }

            let mediumFavicon = FaviconSelector.getMostSuitableFavicon(for: .medium, favicons: favicons)
            let smallFavicon = FaviconSelector.getMostSuitableFavicon(for: .small, favicons: favicons)
            self?.referenceCache.insert(faviconUrls: (smallFavicon?.url, mediumFavicon?.url), documentUrl: documentUrl)

            mainQueueCompletion(smallFavicon, nil)
        }
    }

    func getCachedFavicon(for documentUrl: URL, sizeCategory: Favicon.SizeCategory) -> Favicon? {
        return queue.sync {
            guard let faviconUrl = referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: sizeCategory) else {
                return nil
            }

            return imageCache.get(faviconUrl: faviconUrl)
        }
    }

    func getCachedFavicon(for host: String, sizeCategory: Favicon.SizeCategory) -> Favicon? {
        return queue.sync {
            guard let faviconUrl = referenceCache.getFaviconUrl(for: host, sizeCategory: sizeCategory) else {
                return nil
            }

            return imageCache.get(faviconUrl: faviconUrl)
        }
    }

    // MARK: - Burning

    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        //TODO: Burn

        referenceCache.burn(except: fireproofDomains) {
            self.imageCache.burn(except: fireproofDomains, completion: completion)
        }
    }

    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void) {
        //TODO: Burn

        referenceCache.burnDomains(domains) {
            self.imageCache.burnDomains(domains, completion: completion)
        }
    }

}
