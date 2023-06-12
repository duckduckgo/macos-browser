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
import BrowserServicesKit
import Common

protocol FaviconManagement: AnyObject {

    var areFaviconsLoaded: Bool { get }

    func loadFavicons()

    func handleFaviconLinks(_ faviconLinks: [FaviconUserScript.FaviconLink], documentUrl: URL, completion: @escaping (Favicon?) -> Void)

    func handleFavicons(_ favicons: [Favicon], documentUrl: URL)

    func getCachedFavicon(for documentUrl: URL, sizeCategory: Favicon.SizeCategory) -> Favicon?

    func getCachedFavicon(for host: String, sizeCategory: Favicon.SizeCategory) -> Favicon?

    func getCachedFavicon(forDomainOrAnySubdomain domain: String, sizeCategory: Favicon.SizeCategory) -> Favicon?

    func burnExcept(fireproofDomains: FireproofDomains, bookmarkManager: BookmarkManager, savedLogins: Set<String>, completion: @escaping () -> Void)

    func burnDomains(_ domains: Set<String>, exceptBookmarks bookmarkManager: BookmarkManager, exceptSavedLogins: Set<String>, tld: TLD, completion: @escaping () -> Void)

}

final class FaviconManager: FaviconManagement {

    static let shared = FaviconManager(cacheType: .standard)

    enum CacheType {
        case standard
        case inMemory
    }

    init(cacheType: CacheType) {
        switch cacheType {
        case .standard:
            store = FaviconStore()
        case .inMemory:
            store = FaviconNullStore()
        }
        imageCache = FaviconImageCache(faviconStoring: store)
        referenceCache = FaviconReferenceCache(faviconStoring: store)

        if case .inMemory = cacheType {
            loadFavicons()
        }
    }

    private(set) var store: FaviconStoring

    private let faviconURLSession = URLSession(configuration: .ephemeral)

    @Published var faviconsLoaded = false

    func loadFavicons() {
        imageCache.loadFavicons { _ in
            self.imageCache.cleanOldExcept(fireproofDomains: FireproofDomains.shared,
                                           bookmarkManager: LocalBookmarkManager.shared) {
                self.referenceCache.loadReferences { _ in
                    self.referenceCache.cleanOldExcept(fireproofDomains: FireproofDomains.shared,
                                                       bookmarkManager: LocalBookmarkManager.shared)
                    self.faviconsLoaded = true
                }
            }
        }
    }

    var areFaviconsLoaded: Bool {
        imageCache.loaded && referenceCache.loaded
    }

    // MARK: - Fetching & Cache

    private var imageCache: FaviconImageCache
    private var referenceCache: FaviconReferenceCache

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
            let cachedFavicons: [Favicon] = faviconLinks
                .compactMap { faviconLink -> Favicon? in
                    guard let faviconUrl = URL(string: faviconLink.href) else {
                        return nil
                    }

                    if let favicon = self.imageCache.get(faviconUrl: faviconUrl), favicon.dateCreated > Date.weekAgo {
                        return favicon
                    }

                    return nil
                }

            let favicon = self.handleFaviconReferenceCacheInsertion(documentURL: documentUrl,
                                                                    cachedFavicons: cachedFavicons,
                                                                    newFavicons: newFavicons)

            completion(favicon)
        }
    }

    func handleFavicons(_ newFavicons: [Favicon], documentUrl: URL) {
        // Insert new favicons to cache
        newFavicons.forEach { newFavicon in
            self.imageCache.insert(newFavicon)
        }

        let faviconLinks = newFavicons.map(\.url)

        // Pick most suitable favicons
        let cachedFavicons: [Favicon] = faviconLinks.compactMap { faviconLink -> Favicon? in
            if let favicon = self.imageCache.get(faviconUrl: faviconLink), favicon.dateCreated > Date.weekAgo {
                return favicon
            }

            return nil
        }

        handleFaviconReferenceCacheInsertion(documentURL: documentUrl, cachedFavicons: cachedFavicons, newFavicons: newFavicons)
    }

    @discardableResult
    private func handleFaviconReferenceCacheInsertion(documentURL: URL, cachedFavicons: [Favicon], newFavicons: [Favicon]) -> Favicon? {
        let noFaviconPickedYet = self.referenceCache.getFaviconUrl(for: documentURL, sizeCategory: .small) == nil
        let newFaviconLoaded = !newFavicons.isEmpty
        let currentSmallFaviconUrl = self.referenceCache.getFaviconUrl(for: documentURL, sizeCategory: .small)
        let currentMediumFaviconUrl = self.referenceCache.getFaviconUrl(for: documentURL, sizeCategory: .medium)
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
            let sortedCachedFavicons = cachedFavicons.sorted(by: { $0.longestSide < $1.longestSide })
            let mediumFavicon = FaviconSelector.getMostSuitableFavicon(for: .medium, favicons: sortedCachedFavicons)
            let smallFavicon = FaviconSelector.getMostSuitableFavicon(for: .small, favicons: sortedCachedFavicons)
            self.referenceCache.insert(faviconUrls: (smallFavicon?.url, mediumFavicon?.url), documentUrl: documentURL)
            return smallFavicon
        } else {
            guard let currentSmallFaviconUrl = currentSmallFaviconUrl,
                  let cachedFavicon = self.imageCache.get(faviconUrl: currentSmallFaviconUrl) else {
                      return nil
                  }

            return cachedFavicon
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

    func getCachedFavicon(forDomainOrAnySubdomain domain: String, sizeCategory: Favicon.SizeCategory) -> Favicon? {
        if let favicon = getCachedFavicon(for: domain, sizeCategory: sizeCategory) {
            return favicon
        }

        let availableSubdomains = referenceCache.hostReferences.keys + referenceCache.urlReferences.keys.compactMap { $0.host }
        let subdomain = availableSubdomains.first { subdomain in
            subdomain.hasSuffix(domain)
        }

        if let subdomain {
            return getCachedFavicon(for: subdomain, sizeCategory: sizeCategory)
        }
        return nil
    }

    // MARK: - Burning

    func burnExcept(fireproofDomains: FireproofDomains,
                    bookmarkManager: BookmarkManager,
                    savedLogins: Set<String> = [],
                    completion: @escaping () -> Void) {
        self.referenceCache.burnExcept(fireproofDomains: fireproofDomains,
                                       bookmarkManager: bookmarkManager,
                                       savedLogins: savedLogins) {
            self.imageCache.burnExcept(fireproofDomains: fireproofDomains,
                                       bookmarkManager: bookmarkManager,
                                       savedLogins: savedLogins) {
                completion()
            }
        }
    }

    func burnDomains(_ baseDomains: Set<String>,
                     exceptBookmarks bookmarkManager: BookmarkManager,
                     exceptSavedLogins: Set<String> = [],
                     tld: TLD,
                     completion: @escaping () -> Void) {
        self.referenceCache.burnDomains(baseDomains, exceptBookmarks: bookmarkManager, exceptSavedLogins: exceptSavedLogins, tld: tld) {
            self.imageCache.burnDomains(baseDomains, exceptBookmarks: bookmarkManager, exceptSavedLogins: exceptSavedLogins, tld: tld) {
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
        guard !faviconLinks.isEmpty else {
            completion([])
            return
        }

        let group = DispatchGroup()
        var favicons = [Favicon]()

        faviconLinks.forEach { faviconLink in
            guard let faviconUrl = URL(string: faviconLink.href) else {
                return
            }

            group.enter()
            faviconURLSession.dataTask(with: faviconUrl) { data, _, error in
                guard let data = data, error == nil else {
                    group.leave()
                    return
                }

                let favicon = Favicon(identifier: UUID(),
                                      url: faviconUrl,
                                      image: NSImage(data: data),
                                      relationString: faviconLink.rel,
                                      documentUrl: documentUrl,
                                      dateCreated: Date())
                DispatchQueue.main.async {
                    favicons.append(favicon)
                    group.leave()
                }
            }.resume()
        }

        group.notify(queue: .main) {
            completion(favicons)
        }
    }
}
