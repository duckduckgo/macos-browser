//
//  RecentActivityProvider.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import Combine
import Common
import Foundation
import History
import NewTabPage

protocol DuckPlayerHistoryEntryTitleProviding {
    func title(for historyEntry: NewTabPageDataModel.HistoryEntry) -> String?
}

protocol URLFavoriteStatusProviding: AnyObject {
    func isUrlFavorited(url: URL) -> Bool
}

extension DuckPlayer: DuckPlayerHistoryEntryTitleProviding {}

extension LocalBookmarkManager: URLFavoriteStatusProviding {}

final class RecentActivityProvider: NewTabPageRecentActivityProviding {
    func refreshActivity() -> [NewTabPageDataModel.DomainActivity] {
        Self.calculateRecentActivity(
            with: historyCoordinator.history ?? [],
            urlFavoriteStatusProvider: urlFavoriteStatusProvider,
            duckPlayerHistoryItemTitleProvider: duckPlayerHistoryEntryTitleProvider
        )
    }

    let activityPublisher: AnyPublisher<[NewTabPageDataModel.DomainActivity], Never>

    let historyCoordinator: HistoryCoordinating
    let urlFavoriteStatusProvider: URLFavoriteStatusProviding
    let duckPlayerHistoryEntryTitleProvider: DuckPlayerHistoryEntryTitleProviding

    init(
        historyCoordinator: HistoryCoordinating,
        urlFavoriteStatusProvider: URLFavoriteStatusProviding,
        duckPlayerHistoryEntryTitleProvider: DuckPlayerHistoryEntryTitleProviding = DuckPlayer.shared
    ) {
        self.historyCoordinator = historyCoordinator
        self.urlFavoriteStatusProvider = urlFavoriteStatusProvider
        self.duckPlayerHistoryEntryTitleProvider = duckPlayerHistoryEntryTitleProvider

        activityPublisher = historyCoordinator.historyDictionaryPublisher
            .receive(on: DispatchQueue.main)
            .compactMap { [weak historyCoordinator] _ -> BrowsingHistory? in
                historyCoordinator?.history
            }
            .compactMap { [weak urlFavoriteStatusProvider] history -> [NewTabPageDataModel.DomainActivity]? in
                guard let urlFavoriteStatusProvider else {
                    return nil
                }
                return Self.calculateRecentActivity(
                    with: history,
                    urlFavoriteStatusProvider: urlFavoriteStatusProvider,
                    duckPlayerHistoryItemTitleProvider: duckPlayerHistoryEntryTitleProvider
                )
            }
            .eraseToAnyPublisher()
    }

    private static func calculateRecentActivity(
        with browsingHistory: BrowsingHistory,
        urlFavoriteStatusProvider: URLFavoriteStatusProviding,
        duckPlayerHistoryItemTitleProvider: DuckPlayerHistoryEntryTitleProviding
    ) -> [NewTabPageDataModel.DomainActivity] {

        var activityItems = [DomainActivityRef]()
        var activityItemsByDomain = [String: DomainActivityRef]()

        let oneWeekAgo = Date.weekAgo

        browsingHistory.filter { !$0.failedToLoad && $0.lastVisit > oneWeekAgo }
            .sorted(by: { $0.lastVisit > $1.lastVisit })
            .forEach { historyEntry in

                guard let host = historyEntry.url.host else { return }

                var activityItem = activityItemsByDomain[host]
                if activityItem == nil, let newItem = NewTabPageDataModel.DomainActivity(historyEntry, urlFavoriteStatusProvider: urlFavoriteStatusProvider) {
                    let newItemRef = DomainActivityRef(newItem)
                    activityItems.append(newItemRef)
                    activityItemsByDomain[host] = newItemRef
                    activityItem = newItemRef
                }

                activityItem?.activity.addBlockedEntities(historyEntry.blockedTrackingEntities)
                activityItem?.activity.addPage(fromHistory: historyEntry, dateFormatter: Self.relativeTime)
            }

        activityItems.forEach {
            $0.activity.prettifyTitles(duckPlayerHistoryItemTitleProvider)
            $0.activity.sortTrackingEntities()
        }

        return activityItems.map(\.activity)
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static func relativeTime(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval > -60 {
            return UserText.justNow
        }
        return relativeDateFormatter.localizedString(fromTimeInterval: date.timeIntervalSinceNow)
    }
}

private extension HistoryEntry {
    private enum Const {
        static let wwwPrefix = "www."
    }

    var etldPlusOne: String? {
        guard let domain = url.host else {
            return nil
        }
        return ContentBlocking.shared.tld.eTLDplus1(domain)?.dropping(prefix: Const.wwwPrefix)
    }
}

extension NewTabPageDataModel.DomainActivity {

    init?(_ historyEntry: HistoryEntry, urlFavoriteStatusProvider: URLFavoriteStatusProviding) {
        guard let host = historyEntry.url.host,
              let rootURLString = historyEntry.url.root?.absoluteString.dropping(suffix: "/"),
              let rootURL = rootURLString.url
        else {
            return nil
        }

        let favicon: NewTabPageDataModel.ActivityFavicon? = {
            guard let src = URL.duckFavicon(for: historyEntry.url)?.absoluteString else {
                return nil
            }
            return .init(maxAvailableSize: Int(Favicon.SizeCategory.small.rawValue), src: src)
        }()

        self.init(
            id: historyEntry.identifier.uuidString,
            title: host.droppingWwwPrefix(),
            url: rootURLString,
            etldPlusOne: historyEntry.etldPlusOne,
            favicon: favicon,
            favorite: urlFavoriteStatusProvider.isUrlFavorited(url: rootURL),
            trackingStatus: .init(
                totalCount: Int64(historyEntry.numberOfTrackersBlocked),
                trackerCompanies: historyEntry.blockedTrackingEntities.map(NewTabPageDataModel.TrackingStatus.TrackerCompany.init)
            ),
            history: []
        )
    }

    mutating func addBlockedEntities(_ entities: Set<String>) {
        let trackerCompanies = Set(entities.map(NewTabPageDataModel.TrackingStatus.TrackerCompany.init))
        trackingStatus.trackerCompanies = Array(Set(trackingStatus.trackerCompanies).union(trackerCompanies))
    }

    mutating func addPage(fromHistory entry: HistoryEntry, dateFormatter: (Date) -> String) {
        // Skip root URLs and non-search DDG urls
        guard !entry.url.isRoot || (entry.url.isDuckDuckGo && !entry.url.isDuckDuckGoSearch) else { return  }

        // Max pages that should be shown is 10
        guard history.count < Const.maxPageListSize else { return }

        history.append(.init(relativeTime: dateFormatter(entry.lastVisit), title: entry.title ?? "", url: entry.url.absoluteString))
    }

    mutating func prettifyTitles(_ duckPlayerHistoryItemTitleProvider: DuckPlayerHistoryEntryTitleProviding) {
        var searches = Set<String>()
        var urlsToRemove = [String]()

        let fixedHistory = history.map { historyItem -> NewTabPageDataModel.HistoryEntry in

            var fixedHistoryItem = NewTabPageDataModel.HistoryEntry(relativeTime: historyItem.relativeTime, title: historyItem.title, url: historyItem.url)

            if let url = historyItem.url.url, url.isDuckDuckGoSearch == true {
                if searches.insert(url.searchQuery ?? "?").inserted {
                    fixedHistoryItem.title = url.searchQuery ?? "?"
                } else {
                    urlsToRemove.append(url.absoluteString)
                }
            } else if let title = duckPlayerHistoryItemTitleProvider.title(for: historyItem) {
                fixedHistoryItem.title = title
            } else {
                fixedHistoryItem.title = historyItem.url
                    .dropping(prefix: "https://")
                    .dropping(prefix: "http://")
                    .dropping(prefix: historyItem.url.url?.host ?? "")
            }
            return fixedHistoryItem
        }

        history = fixedHistory.filter { !urlsToRemove.contains($0.url) }
    }

    mutating func sortTrackingEntities(_ contentBlocking: AnyContentBlocking = ContentBlocking.shared) {
        trackingStatus.trackerCompanies = trackingStatus.trackerCompanies.sorted(by: { lhs, rhs in
            contentBlocking.prevalenceForEntity(named: lhs.displayName) > contentBlocking.prevalenceForEntity(named: rhs.displayName)
        })
    }

    private enum Const {
        static let maxPageListSize = 10
    }
}

private final class DomainActivityRef {
    var activity: NewTabPageDataModel.DomainActivity

    init(_ activity: NewTabPageDataModel.DomainActivity) {
        self.activity = activity
    }
}
