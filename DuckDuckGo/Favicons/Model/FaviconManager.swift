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

protocol FaviconManagement {

    var areFaviconsLoaded: Bool { get }
    func loadFavicons()

    func handleFaviconLinks(_ faviconLinks: [FaviconUserScript.FaviconLink],
                            documentUrl: URL,
                            completion: @escaping (Favicon?) -> Void)
    func getCachedFavicon(for documentUrl: URL, sizeCategory: Favicon.SizeCategory) -> Favicon?
    func getCachedFavicon(for host: String, sizeCategory: Favicon.SizeCategory) -> Favicon?

    func burnExcept(fireproofDomains: FireproofDomains,
                    bookmarkManager: BookmarkManager,
                    completion: @escaping () -> Void)
    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void)

}

final class FaviconManager: FaviconManagement {

    static let shared = FaviconManager()

    private let fetchingQueue = DispatchQueue(label: "FaviconManager queue", qos: .userInitiated, attributes: .concurrent)
    private lazy var store: FaviconStoring = FaviconStore()

    func loadFavicons() {
        imageCache.loadFavicons { _ in
            self.imageCache.cleanOldExcept(fireproofDomains: FireproofDomains.shared,
                                           bookmarkManager: LocalBookmarkManager.shared) {
                self.referenceCache.loadReferences { _ in
                    self.referenceCache.cleanOldExcept(fireproofDomains: FireproofDomains.shared,
                                                       bookmarkManager: LocalBookmarkManager.shared)
                }
            }
        }
    }

    var areFaviconsLoaded: Bool {
        imageCache.loaded && referenceCache.loaded
    }

    // MARK: - Fetching & Cache

    private lazy var imageCache = FaviconImageCache(faviconStoring: store)
    private lazy var referenceCache = FaviconReferenceCache(faviconStoring: store)

    func handleFaviconLinks(_ faviconLinks: [FaviconUserScript.FaviconLink],
                            documentUrl: URL,
                            completion: @escaping (Favicon?) -> Void) {
        // Manually add favicon.ico into links
        let faviconLinks = addingFaviconIco(into: faviconLinks, documentUrl: documentUrl)

        // Fetch favicons if needed
        let faviconLinksToFetch = filteringAlreadyFetchedFaviconLinks(from: faviconLinks)
        fetchFavicons(faviconLinks: faviconLinksToFetch, documentUrl: documentUrl) { [weak self] newFavicons in
            guard let self = self else { return }

            // Insert new favicons to cache
            newFavicons.forEach { newFavicon in
                self.imageCache.insert(newFavicon)
            }

            // Pick most suitable favicons
            var cachedFavicons: [Favicon] = faviconLinks
                .compactMap { faviconLink -> Favicon? in
                    guard let faviconUrl = URL(string: faviconLink.href) else {
                        return nil
                    }

                    if let favicon = self.imageCache.get(faviconUrl: faviconUrl), favicon.dateCreated > Date.weekAgo {
                        return favicon
                    } else {
                        assertionFailure("Missing entry for faviconUrl")
                    }

                    return nil
                }

            let noFaviconPickedYet = self.referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: .small) == nil
            let newFaviconLoaded = !newFavicons.isEmpty
            let currentSmallFaviconUrl = self.referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: .small)
            let currentMediumFaviconUrl = self.referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: .medium)
            let cachedFaviconUrls = cachedFavicons.map {$0.url}
            let faviconsOutdated: Bool = {
                if let currentSmallFaviconUrl = currentSmallFaviconUrl, !cachedFaviconUrls.contains(currentSmallFaviconUrl) {
                    return true
                }
                if let currentMediumFaviconUrl = currentMediumFaviconUrl, !cachedFaviconUrls.contains(currentMediumFaviconUrl) {
                    return true
                }
                return false
            }()

            // If we haven't pick a favicon yet or there is a new favicon loaded or favicons are outdated
            // Pick the most suitable favicons. Otherwise use cached references
            if noFaviconPickedYet || newFaviconLoaded || faviconsOutdated {
                cachedFavicons = cachedFavicons.sorted(by: { $0.image.size.width < $1.image.size.width })
                let mediumFavicon = FaviconSelector.getMostSuitableFavicon(for: .medium, favicons: cachedFavicons)
                let smallFavicon = FaviconSelector.getMostSuitableFavicon(for: .small, favicons: cachedFavicons)
                self.referenceCache.insert(faviconUrls: (smallFavicon?.url, mediumFavicon?.url), documentUrl: documentUrl)
                completion(smallFavicon)
            } else {
                guard let currentSmallFaviconUrl = currentSmallFaviconUrl,
                      let cachedFavicon = self.imageCache.get(faviconUrl: currentSmallFaviconUrl) else {
                          completion(nil)
                          return
                      }

                completion(cachedFavicon)
            }
        }
    }

    func getCachedFavicon(for documentUrl: URL, sizeCategory: Favicon.SizeCategory) -> Favicon? {
        guard let faviconUrl = referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: sizeCategory) else {
            return nil
        }

        return imageCache.get(faviconUrl: faviconUrl)
    }

    func getCachedFavicon(for host: String, sizeCategory: Favicon.SizeCategory) -> Favicon? {
        guard let faviconUrl = referenceCache.getFaviconUrl(for: host, sizeCategory: sizeCategory) else {
            return nil
        }

        return imageCache.get(faviconUrl: faviconUrl)
    }

    // MARK: - Burning

    func burnExcept(fireproofDomains: FireproofDomains,
                    bookmarkManager: BookmarkManager,
                    completion: @escaping () -> Void) {
        self.referenceCache.burnExcept(fireproofDomains: fireproofDomains,
                                       bookmarkManager: bookmarkManager) {
            self.imageCache.burnExcept(fireproofDomains: fireproofDomains,
                                       bookmarkManager: bookmarkManager) {
                completion()
            }
        }
    }

    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void) {
        self.referenceCache.burnDomains(domains) {
            self.imageCache.burnDomains(domains) {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    // MARK: - Private

    private func addingFaviconIco(into faviconLinks: [FaviconUserScript.FaviconLink], documentUrl: URL) -> [FaviconUserScript.FaviconLink] {
        var faviconLinks = faviconLinks
        if let host = documentUrl.host {
            let faviconIcoLink = FaviconUserScript.FaviconLink(href: "\(URL.NavigationalScheme.https.separated())\(host)/favicon.ico",
                                                               rel: "favicon.ico")
            faviconLinks.append(faviconIcoLink)
        }
        return faviconLinks
    }

    private func filteringAlreadyFetchedFaviconLinks(from faviconLinks: [FaviconUserScript.FaviconLink]) -> [FaviconUserScript.FaviconLink] {
        return faviconLinks.filter { faviconLink in
            guard let faviconUrl = URL(string: faviconLink.href) else {
                return false
            }

            if let favicon = imageCache.get(faviconUrl: faviconUrl), favicon.dateCreated > Date.weekAgo {
                return false
            } else {
                return true
            }
        }
    }

    private func fetchFavicons(faviconLinks: [FaviconUserScript.FaviconLink], documentUrl: URL, completion: @escaping ([Favicon]) -> Void) {

        func mainQueueCompletion(_ favicons: [Favicon]) {
            DispatchQueue.main.async {
                completion(favicons)
            }
        }

        guard !faviconLinks.isEmpty else {
            completion([])
            return
        }

        fetchingQueue.async(flags: .barrier) {
            let favicons: [Favicon] = faviconLinks
                .compactMap { faviconLink -> Favicon? in
                    guard let faviconUrl = URL(string: faviconLink.href) else {
                        return nil
                    }

                    if let fetchedImage = NSImage(contentsOf: faviconUrl), fetchedImage.isValid {
                        return Favicon(identifier: UUID(),
                                       url: faviconUrl,
                                       image: fetchedImage,
                                       relationString: faviconLink.rel,
                                       documentUrl: documentUrl,
                                       dateCreated: Date())

                    } else {
                        // To prevent reloading of non-valid images
                        return Favicon(identifier: UUID(),
                                       url: faviconUrl,
                                       image: NSImage(),
                                       relationString: faviconLink.rel,
                                       documentUrl: documentUrl,
                                       dateCreated: Date())
                    }
                }
            mainQueueCompletion(favicons)
        }
    }
}
