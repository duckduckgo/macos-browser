//
//  HomePageRecentlyVisitedModel.swift
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

extension HomePage.Models {

final class RecentlyVisitedPageModel: ObservableObject {

    let actualTitle: String?
    let url: URL
    let visited: Date

    @Published var displayTitle: String

    init(actualTitle: String?, url: URL, visited: Date) {
        self.actualTitle = actualTitle
        self.url = url
        self.visited = visited
        self.displayTitle = actualTitle ?? "" // Default, but might change
    }

}

final class RecentlyVisitedSiteModel: ObservableObject {

    let domain: String

    var blockedEntities = Set<String>()

    @Published var isFavorite: Bool
    @Published var blockedEntityDisplayNames = [String]()
    @Published var pages = [RecentlyVisitedPageModel]()

    init(domain: String, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.domain = domain
        if let url = domain.url {
            isFavorite = bookmarkManager.isUrlFavorited(url: url)
        } else {
            isFavorite = false
        }
    }

    func addBlockedEntities(_ entities: Set<String>) {
        blockedEntities = blockedEntities.union(entities)
    }

    func addPage(fromHistory history: HistoryEntry, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        guard !history.url.isRoot else { return }
        pages.append(RecentlyVisitedPageModel(actualTitle: history.title, url: history.url, visited: history.lastVisit))
    }

    func fixDisplayTitles() {
        var pagesByTitle = [String: RecentlyVisitedPageModel]()
        var urlsToRemove = [URL]()

        pages.forEach {
            if $0.url.isRoot { // Don't show root pages

                urlsToRemove.append($0.url)

            } else if $0.actualTitle == nil || $0.actualTitle?.trimWhitespace().isEmpty == true { // Blank titles

                $0.displayTitle = $0.url.path

            } else if let actualTitle = $0.actualTitle {

                if $0.url.isDuckDuckGoSearch {
                    $0.displayTitle = $0.url.searchQuery ?? actualTitle
                }

                if let previousPageWithTitle = pagesByTitle[actualTitle] { // Duplicate titles
                    // This is a duplicate title.  If it's a search, remove the duplicate, otherwise make the display title unique
                    if $0.url.isDuckDuckGoSearch {
                        urlsToRemove.append($0.url)
                    } else {
                        $0.displayTitle = $0.url.path
                        previousPageWithTitle.displayTitle = $0.url.path
                    }

                } else {

                    // Remember we've seen this title 
                    pagesByTitle[actualTitle] = $0

                }

            }
        }

        print("*** removing URLs", urlsToRemove)
        pages = pages.filter { !urlsToRemove.contains($0.url) }
    }

    func fixDisplayEntities(_ contentBlocking: ContentBlocking = ContentBlocking.shared) {
        blockedEntityDisplayNames = blockedEntities.filter { !$0.isEmpty }.sorted(by: { l, r in
            contentBlocking.prevalenceForEntity(named: l) > contentBlocking.prevalenceForEntity(named: r)
        }).map {
            contentBlocking.displayNameForEntity(named: $0)
        }
    }

}

final class RecentlyVisitedModel: ObservableObject {

    @Published var numberOfTrackersBlocked = 0
    @Published var numberOfWebsites = 0
    @Published var recentSites = [RecentlyVisitedSiteModel]()

    func refreshWithHistory(_ history: [HistoryEntry]) {
        var numberOfTrackersBlocked = 0

        var recentSites = [RecentlyVisitedSiteModel]()
        var sitesByDomain = [String: RecentlyVisitedSiteModel]()

        history.forEach {
            numberOfTrackersBlocked += $0.numberOfTrackersBlocked
            guard let host = $0.url.host?.dropWWW() else { return }

            var site = sitesByDomain[host]
            if site == nil {
                let newSite = RecentlyVisitedSiteModel(domain: host)
                sitesByDomain[host] = newSite
                recentSites.append(newSite)
                site = newSite
            }

            site?.addBlockedEntities($0.blockedTrackingEntities)
            site?.addPage(fromHistory: $0)
        }

        recentSites.forEach {
            $0.fixDisplayTitles()
            $0.fixDisplayEntities()
        }

        self.numberOfTrackersBlocked = numberOfTrackersBlocked
        self.numberOfWebsites = sitesByDomain.count
        self.recentSites = recentSites
    }

}

}

extension ContentBlocking {

    func prevalenceForEntity(named entityName: String) -> Double {
        return trackerDataManager.trackerData.entities[entityName]?.prevalence ?? 0.0
    }

    func displayNameForEntity(named entityName: String) -> String {
        return trackerDataManager.trackerData.entities[entityName]?.displayName ?? entityName
    }

}
