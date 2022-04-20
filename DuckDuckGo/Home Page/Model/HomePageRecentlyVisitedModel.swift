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
import SwiftUI

extension HomePage.Models {

final class RecentlyVisitedModel: ObservableObject {

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    } ()

    private let fire = Fire()

    @UserDefaultsWrapper(key: .homePageShowPagesOnHover, defaultValue: false)
    private static var showPagesOnHoverSetting: Bool

    @Published var numberOfTrackersBlocked = 0
    @Published var recentSites = [RecentlyVisitedSiteModel]()
    @Published var showPagesOnHover: Bool {
        didSet {
            Self.showPagesOnHoverSetting = showPagesOnHover
        }
    }

    let open: (URL) -> Void

    init(open: @escaping (URL) -> Void) {
        self.open = open
        showPagesOnHover = Self.showPagesOnHoverSetting
    }

    func refreshWithHistory(_ history: [HistoryEntry]) {
        var numberOfTrackersBlocked = 0

        var recentSites = [RecentlyVisitedSiteModel]()
        var sitesByDomain = [String: RecentlyVisitedSiteModel]()

        let aWeekAgo = Date.weekAgo

        history.filter { !$0.failedToLoad && $0.lastVisit > aWeekAgo }
            .sorted(by: { $0.lastVisit > $1.lastVisit })
            .forEach {

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
            $0.fixEntities()
        }

        self.numberOfTrackersBlocked = numberOfTrackersBlocked
        self.recentSites = recentSites
    }

    func burn(_ site: RecentlyVisitedSiteModel) {
        fire.burnDomains(Set<String>([site.domain]))
        recentSites = recentSites.filter { $0.domain != site.domain }
        numberOfTrackersBlocked -= site.numberOfTrackersBlocked
    }

    func toggleFavoriteSite(_ site: RecentlyVisitedSiteModel, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        guard let url = site.domain.url else { return }
        if let bookmark = bookmarkManager.getBookmark(for: url) {
            bookmark.isFavorite.toggle()
            bookmarkManager.update(bookmark: bookmark)
            site.isFavorite = bookmark.isFavorite
        } else {
            bookmarkManager.makeBookmark(for: url, title: site.domain.dropWWW(), isFavorite: true)
            site.isFavorite = true
        }
    }

    func open(_ site: RecentlyVisitedSiteModel) {
        guard let url = site.domain.url else { return }
        self.open(url)
    }

    func relativeTime(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval > -60 {
            return "Just now"
        }
        return Self.relativeDateFormatter.localizedString(fromTimeInterval: date.timeIntervalSinceNow)
    }

}

final class RecentlyVisitedPageModel: ObservableObject {

    let actualTitle: String?
    let url: URL
    let visited: Date

    @Published var displayTitle: String

    init(actualTitle: String?, url: URL, visited: Date) {
        self.actualTitle = actualTitle
        self.url = url
        self.visited = visited

        // This gets fixed in the parent model, when iterating over history items
        self.displayTitle = actualTitle ?? ""
    }

}

final class RecentlyVisitedSiteModel: ObservableObject {

    @UserDefaultsWrapper(key: .homePageShowPageTitles, defaultValue: false)
    private var showTitlesForPagesSetting: Bool

    let maxPageListSize = 10

    let domain: String

    @Published var isFavorite: Bool
    @Published var blockedEntities = [String]()
    @Published var pages = [RecentlyVisitedPageModel]()
    @Published var numberOfTrackersBlocked = 0
    @Published var trackersFound = false

    // These are used by the burning animation
    @Published var isBurning = false
    @Published var isHidden = false

    init(domain: String, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        self.domain = domain
        if let url = domain.url {
            isFavorite = bookmarkManager.isUrlFavorited(url: url)
        } else {
            isFavorite = false
        }
    }

    func addBlockedEntities(_ entities: Set<String>) {
        blockedEntities = [String](Set<String>(blockedEntities).union(entities))
    }

    func addPage(fromHistory entry: HistoryEntry, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared) {
        numberOfTrackersBlocked += entry.numberOfTrackersBlocked

        if entry.trackersFound {
            trackersFound = true
        }

        // Skip root URLs and non-search DDG urls
        guard !entry.url.isRoot || (entry.url.isDuckDuckGo && !entry.url.isDuckDuckGoSearch) else { return  }

        // Max pages that should be shown is 10
        guard pages.count < maxPageListSize else { return }

        pages.append(RecentlyVisitedPageModel(actualTitle: entry.title, url: entry.url, visited: entry.lastVisit))
    }

    func fixDisplayTitles() {
        var searches = Set<String>()
        var urlsToRemove = [URL]()

        pages.forEach {

            if $0.url.isDuckDuckGoSearch {

                if searches.insert($0.url.searchQuery ?? "?").inserted {
                    $0.displayTitle = $0.url.searchQuery ?? "?"
                } else {
                    urlsToRemove.append($0.url)
                }

            } else if !showTitlesForPagesSetting {

                $0.displayTitle = $0.url.absoluteString
                    .drop(prefix: "https://")
                    .drop(prefix: "http://")
                    .drop(prefix: $0.url.host ?? "")

            } else if $0.actualTitle?.isEmpty ?? true { // Blank titles

                $0.displayTitle = $0.url.path

            } else {

                $0.displayTitle = $0.actualTitle ?? $0.url.path

            }
        }

        pages = pages.filter { !urlsToRemove.contains($0.url) }
    }

    func fixEntities(_ contentBlocking: ContentBlocking = ContentBlocking.shared) {
        blockedEntities = blockedEntities.filter { !$0.isEmpty }.sorted(by: { l, r in
            contentBlocking.prevalenceForEntity(named: l) > contentBlocking.prevalenceForEntity(named: r)
        })
    }

    func entityImageName(_ entityName: String) -> String {
        return entityDisplayName(entityName).slugfiscated()
    }

    func entityDisplayName(_ entityName: String, _ contentBlocking: ContentBlocking = ContentBlocking.shared) -> String {
        return contentBlocking.displayNameForEntity(named: entityName)
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

extension String {

    static let tldSuffixes = (try? NSRegularExpression(pattern: "\\.[a-z]+$", options: []))!
    static let removeNonAlpha = (try? NSRegularExpression(pattern: "[^a-z0-9]", options: []))!

    func slugfiscated() -> String {
        let lower = NSMutableString(string: self.lowercased())
        Self.tldSuffixes.replaceMatches(in: lower, options: [], range: NSRange(location: 0, length: lower.length), withTemplate: "")
        Self.removeNonAlpha.replaceMatches(in: lower, options: [], range: NSRange(location: 0, length: lower.length), withTemplate: "")
        return lower as String
    }

}
