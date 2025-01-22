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
import Foundation
import History
import NewTabPage

final class RecentActivityProvider {
    let activityPublisher: AnyPublisher<[NewTabPageDataModel.DomainActivity], Never>

    init(historyCoordinator: HistoryCoordinating, bookmarkManager: BookmarkManager) {
        activityPublisher = historyCoordinator.historyDictionaryPublisher
            .receive(on: DispatchQueue.main)
            .compactMap { [weak historyCoordinator] _ -> BrowsingHistory? in
                historyCoordinator?.history
            }
            .compactMap { [weak bookmarkManager] history -> [NewTabPageDataModel.DomainActivity]? in
                guard let bookmarkManager else {
                    return nil
                }
                return Self.calculateRecentActivity(with: history, bookmarkManager: bookmarkManager)
            }
            .eraseToAnyPublisher()
    }

    private static func calculateRecentActivity(with browsingHistory: BrowsingHistory, bookmarkManager: BookmarkManager) -> [NewTabPageDataModel.DomainActivity] {

        var activityItems = [DomainActivityRef]()
        var activityItemsByDomain = [String: DomainActivityRef]()

        let oneWeekAgo = Date.weekAgo

        browsingHistory.filter { !$0.failedToLoad && $0.lastVisit > oneWeekAgo }
            .sorted(by: { $0.lastVisit > $1.lastVisit })
            .forEach { historyEntry in

                guard let host = historyEntry.url.host else { return }

                var activityItem = activityItemsByDomain[host]
                if activityItem == nil, let newItem = NewTabPageDataModel.DomainActivity(historyEntry, bookmarkManager: bookmarkManager) {
                    let newItemRef = DomainActivityRef(newItem)
                    activityItems.append(newItemRef)
                    activityItemsByDomain[host] = newItemRef
                    activityItem = newItemRef
                }

                activityItem?.activity.addBlockedEntities(historyEntry.blockedTrackingEntities)
                activityItem?.activity.addPage(fromHistory: historyEntry, dateFormatter: Self.relativeTime)
            }

        activityItems.forEach {
            $0.activity.prettifyTitles()
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
            return "Just now"
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

    init?(_ historyEntry: HistoryEntry, bookmarkManager: BookmarkManager) {
        guard let host = historyEntry.url.host?.droppingWwwPrefix() else {
            return nil
        }

        self.init(
            id: historyEntry.identifier.uuidString,
            title: host,
            url: host,
            etldPlusOne: historyEntry.etldPlusOne,
            favicon: URL.duckFavicon(for: historyEntry.url)?.absoluteString,
            favorite: bookmarkManager.isUrlFavorited(url: historyEntry.url),
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

    mutating func addPage(fromHistory entry: HistoryEntry, bookmarkManager: BookmarkManager = LocalBookmarkManager.shared, dateFormatter: (Date) -> String) {
        // Skip root URLs and non-search DDG urls
        guard !entry.url.isRoot || (entry.url.isDuckDuckGo && !entry.url.isDuckDuckGoSearch) else { return  }

        // Max pages that should be shown is 10
        guard history.count < Const.maxPageListSize else { return }

        history.append(.init(relativeTime: dateFormatter(entry.lastVisit), title: entry.title ?? "", url: entry.url.absoluteString))
    }

    mutating func prettifyTitles() {
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
            } else if let title = DuckPlayer.shared.title(for: historyItem) {
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
