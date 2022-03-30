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

protocol FaviconManagement {

    var areFaviconsLoaded: Bool { get }
    func loadFavicons()

    func handleFaviconLinks(_ faviconLinks: [FaviconUserScript.FaviconLink],
                            documentUrl: URL,
                            onSmallFaviconReady: @escaping (Favicon?) -> Void)
    func getCachedFavicon(for documentUrl: URL, sizeCategory: Favicon.SizeCategory) -> Favicon?
    func getCachedFavicon(for host: String, sizeCategory: Favicon.SizeCategory) -> Favicon?

    func burnExcept(fireproofDomains: FireproofDomains,
                    bookmarkManager: BookmarkManager,
                    completion: @escaping () -> Void)
    func burnDomains(_ domains: Set<String>,
                     except bookmarkManager: BookmarkManager,
                     completion: @escaping () -> Void)

}

final class FaviconManager: FaviconManagement {

    static let shared = FaviconManager()

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
                            onSmallFaviconReady: @escaping (Favicon?) -> Void) {
        // Manually add favicon.ico into links
        let faviconLinks = addingFaviconIco(into: faviconLinks, documentUrl: documentUrl)

        // Determine whether we need to fetch images
        let faviconLinksToFetch = filteringAlreadyFetchedFaviconLinks(from: faviconLinks)

        // Get current cache entries for the document URL
        let currentSmallFaviconUrl = self.referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: .small)
        let currentMediumFaviconUrl = self.referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: .medium)

        fetchFavicons(faviconLinks: faviconLinksToFetch,
                      documentUrl: documentUrl,
                      shouldProvideTemporaryFavicon: currentSmallFaviconUrl == nil,
                      temporaryFaviconLoaded: {
            onSmallFaviconReady($0)
        },
                      completion: { [weak self] newFavicons in
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
                    }

                    return nil
                }

            let noFaviconPickedYet = self.referenceCache.getFaviconUrl(for: documentUrl, sizeCategory: .small) == nil
            let newFaviconLoaded = !newFavicons.isEmpty
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
                cachedFavicons = cachedFavicons.sorted(by: { $0.longestSide < $1.longestSide })
                let mediumFavicon = FaviconSelector.getMostSuitableFavicon(for: .medium, favicons: cachedFavicons)
                let smallFavicon = FaviconSelector.getMostSuitableFavicon(for: .small, favicons: cachedFavicons)
                self.referenceCache.insert(faviconUrls: (smallFavicon?.url, mediumFavicon?.url), documentUrl: documentUrl)
                onSmallFaviconReady(smallFavicon)
            } else {
                guard let currentSmallFaviconUrl = currentSmallFaviconUrl,
                      let cachedFavicon = self.imageCache.get(faviconUrl: currentSmallFaviconUrl) else {
                          onSmallFaviconReady(nil)
                          return
                      }

                onSmallFaviconReady(cachedFavicon)
            }
        })
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

    func burnDomains(_ domains: Set<String>,
                     except bookmarkManager: BookmarkManager,
                     completion: @escaping () -> Void) {
        self.referenceCache.burnDomains(domains, except: bookmarkManager) {
            self.imageCache.burnDomains(domains, except: bookmarkManager) {
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

    private let faviconURLSession = URLSession(configuration: .ephemeral)

    private func fetchFavicons(faviconLinks: [FaviconUserScript.FaviconLink],
                               documentUrl: URL,
                               shouldProvideTemporaryFavicon: Bool,
                               temporaryFaviconLoaded: @escaping (Favicon) -> Void,
                               completion: @escaping ([Favicon]) -> Void) {

        // If necessary, load a temporary favicon as a priority
        func fetchTemporaryFavicon(completion: @escaping (Favicon?, [FaviconUserScript.FaviconLink]?) -> Void) {
            var faviconLinks = faviconLinks

            let temporaryFaviconIndex = temporaryFaviconIndex(in: faviconLinks)

            if shouldProvideTemporaryFavicon,
               let temporaryFaviconIndex = temporaryFaviconIndex,
               let temporaryFaviconUrl = URL(string: faviconLinks[temporaryFaviconIndex].href) {
                let temporaryFaviconLink = faviconLinks[temporaryFaviconIndex]
                faviconLinks.remove(at: temporaryFaviconIndex)

                faviconURLSession.dataTask(with: temporaryFaviconUrl) { data, _, error in
                    guard let data = data, error == nil else {
                        DispatchQueue.main.async {
                            completion(nil, nil)
                        }
                        return
                    }

                    let favicon = Favicon(url: temporaryFaviconUrl, data: data, faviconLink: temporaryFaviconLink, documentUrl: documentUrl)
                    DispatchQueue.main.async {
                        completion(favicon, faviconLinks)
                    }
                }.resume()

            } else {
                completion(nil, nil)
            }
        }

        func fetchAllFavicons(temporaryFavicon: Favicon?, faviconLinks: [FaviconUserScript.FaviconLink], completion: @escaping ([Favicon]) -> Void) {
            let group = DispatchGroup()
            var favicons: [Favicon]
            if let temporaryFavicon = temporaryFavicon {
                favicons = [temporaryFavicon]
            } else {
                favicons = []
            }

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

                    let favicon = Favicon(url: faviconUrl, data: data, faviconLink: faviconLink, documentUrl: documentUrl)

                    DispatchQueue.main.async {
                        favicons.append(favicon)
                        group.leave()
                    }
                }.resume()
            }

            group.notify(queue: .main) {
                if let temporaryFavicon = temporaryFavicon {
                    favicons.append(temporaryFavicon)
                }
                completion(favicons)
            }
        }

        guard !faviconLinks.isEmpty else {
            completion([])
            return
        }

        fetchTemporaryFavicon { temporaryFavicon, newFaviconLinks in
            // Provide temporary favicon if needed
            if let temporaryFavicon = temporaryFavicon, shouldProvideTemporaryFavicon {
                temporaryFaviconLoaded(temporaryFavicon)
            }

            let faviconLinks = newFaviconLinks ?? faviconLinks
            fetchAllFavicons(temporaryFavicon: temporaryFavicon, faviconLinks: faviconLinks, completion: completion)
        }

    }

    private func temporaryFaviconIndex(in faviconLinks: [FaviconUserScript.FaviconLink]) -> Int? {
        guard faviconLinks.count > 1 else { return nil }

        return faviconLinks.firstIndex(where: { faviconLink in
            let relation = Favicon.Relation(relationString: faviconLink.rel)
            return relation == .favicon || relation == .icon
        })
    }

}

extension Favicon {

    init(url: URL, data: Data, faviconLink: FaviconUserScript.FaviconLink, documentUrl: URL) {
        self.init(identifier: UUID(),
                  url: url,
                  image: NSImage(data: data),
                  relationString: faviconLink.rel,
                  documentUrl: documentUrl,
                  dateCreated: Date())
    }

}
