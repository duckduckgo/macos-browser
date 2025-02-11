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

protocol TrackerEntityPrevalenceComparing {
    func isPrevalence(for lhsEntityName: String, greaterThan rhsEntityName: String) -> Bool
}

extension DuckPlayer: DuckPlayerHistoryEntryTitleProviding {}

extension LocalBookmarkManager: URLFavoriteStatusProviding {}

struct ContentBlockingPrevalenceComparator: TrackerEntityPrevalenceComparing {
    let contentBlocking: ContentBlockingProtocol

    func isPrevalence(for lhsEntityName: String, greaterThan rhsEntityName: String) -> Bool {
        contentBlocking.prevalenceForEntity(named: lhsEntityName) > contentBlocking.prevalenceForEntity(named: rhsEntityName)
    }
}

final class RecentActivityProvider: NewTabPageRecentActivityProviding {
    func refreshActivity() -> [NewTabPageDataModel.DomainActivity] {
        Self.calculateRecentActivity(
            with: historyCoordinator.history ?? [],
            urlFavoriteStatusProvider: urlFavoriteStatusProvider,
            duckPlayerHistoryItemTitleProvider: duckPlayerHistoryEntryTitleProvider,
            trackerEntityPrevalenceComparator: trackerEntityPrevalenceComparator
        )
    }

    let activityPublisher: AnyPublisher<[NewTabPageDataModel.DomainActivity], Never>

    let historyCoordinator: HistoryCoordinating
    let urlFavoriteStatusProvider: URLFavoriteStatusProviding
    let duckPlayerHistoryEntryTitleProvider: DuckPlayerHistoryEntryTitleProviding
    let trackerEntityPrevalenceComparator: TrackerEntityPrevalenceComparing

    init(
        historyCoordinator: HistoryCoordinating,
        urlFavoriteStatusProvider: URLFavoriteStatusProviding,
        duckPlayerHistoryEntryTitleProvider: DuckPlayerHistoryEntryTitleProviding,
        trackerEntityPrevalenceComparator: TrackerEntityPrevalenceComparing
    ) {
        self.historyCoordinator = historyCoordinator
        self.urlFavoriteStatusProvider = urlFavoriteStatusProvider
        self.duckPlayerHistoryEntryTitleProvider = duckPlayerHistoryEntryTitleProvider
        self.trackerEntityPrevalenceComparator = trackerEntityPrevalenceComparator

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
                    duckPlayerHistoryItemTitleProvider: duckPlayerHistoryEntryTitleProvider,
                    trackerEntityPrevalenceComparator: trackerEntityPrevalenceComparator
                )
            }
            .eraseToAnyPublisher()
    }

    private static func calculateRecentActivity(
        with browsingHistory: BrowsingHistory,
        urlFavoriteStatusProvider: URLFavoriteStatusProviding,
        duckPlayerHistoryItemTitleProvider: DuckPlayerHistoryEntryTitleProviding,
        trackerEntityPrevalenceComparator: TrackerEntityPrevalenceComparing
    ) -> [NewTabPageDataModel.DomainActivity] {
        guard !browsingHistory.isEmpty else {
            return []
        }

        var activityItems = [DomainActivityRef]()
        var activityItemsByDomain = [String: DomainActivityRef]()

        browsingHistory
            .filter(\.isValidForRecentActivity)
            .sorted(by: { $0.lastVisit > $1.lastVisit })
            .forEach { historyEntry in

                guard let host = historyEntry.url.host else { return }

                let activityItem: DomainActivityRef? = {
                    let cachedItem = activityItemsByDomain[host]
                    if let cachedItem {
                        return cachedItem
                    }
                    guard let newItem = NewTabPageDataModel.DomainActivity(historyEntry, urlFavoriteStatusProvider: urlFavoriteStatusProvider) else {
                        return nil
                    }
                    let newItemRef = DomainActivityRef(newItem)
                    activityItems.append(newItemRef)
                    activityItemsByDomain[host] = newItemRef
                    return newItemRef
                }()

                activityItem?.activity.addBlockedEntities(from: historyEntry)
                activityItem?.activity.addPage(fromHistory: historyEntry, dateFormatter: Self.relativeTime)
            }

        activityItems.forEach {
            $0.activity.prettifyTitles(duckPlayerHistoryItemTitleProvider)
            $0.activity.sortTrackingEntities(using: trackerEntityPrevalenceComparator)
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
        let isWithinLastMinute = interval > -60
        return isWithinLastMinute ? UserText.justNow : relativeDateFormatter.localizedString(fromTimeInterval: interval)
    }
}

extension HistoryEntry {
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
            guard let src = URL.duckFavicon(for: rootURL)?.absoluteString else {
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
            trackersFound: historyEntry.trackersFound,
            trackingStatus: .init(totalCount: 0, trackerCompanies: []), // keep this empty because it's updated separately
            history: []
        )
    }

    mutating func addBlockedEntities(from entry: HistoryEntry) {
        let trackerCompanies = Set(entry.blockedTrackingEntities.filter({ !$0.isEmpty }).map(NewTabPageDataModel.TrackingStatus.TrackerCompany.init))
        trackingStatus.totalCount += Int64(entry.numberOfTrackersBlocked)
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
        var searchQueries = Set<String>()

        history = history.compactMap { historyItem -> NewTabPageDataModel.HistoryEntry? in
            var fixedHistoryItem = NewTabPageDataModel.HistoryEntry(relativeTime: historyItem.relativeTime, title: historyItem.title, url: historyItem.url)

            if let url = historyItem.url.url, url.isDuckDuckGoSearch == true {
                let searchQuery = url.searchQuery ?? "?"
                guard searchQueries.insert(searchQuery).inserted else {
                    return nil // Ignore history items for duplicated search queries
                }
                fixedHistoryItem.title = url.searchQuery ?? "?"
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
    }

    mutating func sortTrackingEntities(using comparator: TrackerEntityPrevalenceComparing) {
        trackingStatus.trackerCompanies = trackingStatus.trackerCompanies.sorted(by: { lhs, rhs in
            comparator.isPrevalence(for: lhs.displayName, greaterThan: rhs.displayName)
        })
    }

    private enum Const {
        static let maxPageListSize = 10
    }
}

extension HistoryEntry {
    var isValidForRecentActivity: Bool {
        !failedToLoad && lastVisit > Date.weekAgo
    }
}

/**
 * This helper class wraps `NewTabPageDataModel.DomainActivity` in a reference type, so that
 * an array of activities can be mutated.
 */
private final class DomainActivityRef {
    var activity: NewTabPageDataModel.DomainActivity

    init(_ activity: NewTabPageDataModel.DomainActivity) {
        self.activity = activity
    }
}
