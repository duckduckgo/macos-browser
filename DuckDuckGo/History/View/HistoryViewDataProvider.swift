//
//  HistoryViewDataProvider.swift
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

import Foundation
import History
import HistoryView

protocol HistoryDeleting: AnyObject {
    func delete(_ visits: [Visit]) async
}

extension HistoryCoordinator: HistoryDeleting {
    func delete(_ visits: [Visit]) async {
        await withCheckedContinuation { continuation in
            burnVisits(visits) {
                continuation.resume()
            }
        }
    }
}

struct HistoryViewGrouping {
    let range: DataModel.HistoryRange
    let items: [DataModel.HistoryItem]

    init(range: DataModel.HistoryRange, visits: [DataModel.HistoryItem]) {
        self.range = range
        self.items = visits
    }

    init?(_ historyGrouping: HistoryGrouping, dateFormatter: HistoryViewDateFormatting) {
        guard let range = DataModel.HistoryRange(date: historyGrouping.date, referenceDate: Date()) else {
            return nil
        }
        self.range = range
        items = historyGrouping.visits.compactMap { DataModel.HistoryItem($0, dateFormatter: dateFormatter) }
    }
}

final class HistoryViewDataProvider: HistoryView.DataProviding {

    init(historyGroupingDataSource: HistoryGroupingDataSource & HistoryCoordinating & HistoryDeleting, dateFormatter: HistoryViewDateFormatting = DefaultHistoryViewDateFormatter()) {
        self.dateFormatter = dateFormatter
        historyGroupingProvider = HistoryGroupingProvider(dataSource: historyGroupingDataSource)
        historyCoordinator = historyGroupingDataSource
    }

    func resetCache() async {
        lastQuery = nil
        await populateVisits()
    }

    @MainActor
    private func populateVisits() {
        var olderHistoryItems = [DataModel.HistoryItem]()
        var olderVisits = [Visit]()

        groupings = historyGroupingProvider.getVisitGroupings()
            .compactMap { historyGrouping -> HistoryViewGrouping? in
                guard let grouping = HistoryViewGrouping(historyGrouping, dateFormatter: dateFormatter) else {
                    return nil
                }
                guard grouping.range != .older else {
                    olderHistoryItems.append(contentsOf: grouping.items)
                    olderVisits.append(contentsOf: historyGrouping.visits)
                    return nil
                }
                visitsByRange[grouping.range] = historyGrouping.visits
                return grouping
            }

        if !olderHistoryItems.isEmpty {
            groupings.append(.init(range: .older, visits: olderHistoryItems))
        }
        if !olderVisits.isEmpty {
            visitsByRange[.older] = olderVisits
        }

        self.historyItems = groupings.flatMap(\.items)
    }

    var ranges: [DataModel.HistoryRange] {
        var ranges: [DataModel.HistoryRange] = [.all]
        ranges.append(contentsOf: groupings.map(\.range))
        return ranges
    }

    func visits(for query: DataModel.HistoryQueryKind, limit: Int, offset: Int) async -> HistoryView.DataModel.HistoryItemsBatch {
        let items = perform(query)
        let visits = items.chunk(with: limit, offset: offset)
        let finished = items.count < limit
        return DataModel.HistoryItemsBatch(finished: finished, visits: visits)
    }

    func deleteVisits(for range: DataModel.HistoryRange) async {
        let startDate = Date()
        let history = Task { @MainActor in
            self.historyCoordinator.history
        }
        guard let history = await history.value else {
            return
        }
        let fetchDate = Date()
        print("Fetching history took \(fetchDate.timeIntervalSince(startDate)) s")
        let date = lastQuery?.date ?? Date()
        let visits: [Visit] = {
            let allVisits: [Visit] = history.flatMap(\.visits)
            guard let dateRange = range.dateRange(for: date) else {
                return allVisits
            }
            return allVisits.filter { dateRange.contains($0.date) }
        }()
        let filterDate = Date()
        print("Filtering history took \(filterDate.timeIntervalSince(startDate)) s")

        await historyCoordinator.delete(visits)
        await resetCache()
        print("Deleting history took \(Date().timeIntervalSince(startDate)) s")
    }

    private func perform(_ query: DataModel.HistoryQueryKind) -> [DataModel.HistoryItem] {
        if let lastQuery, lastQuery.query == query {
            return lastQuery.items
        }

        let items: [DataModel.HistoryItem] = {
            switch query {
            case .rangeFilter(.all), .searchTerm(""):
                return historyItems
            case .rangeFilter(let range):
                return groupings.first(where: { $0.range == range })?.items ?? []
            case .searchTerm(let term):
                return historyItems.filter { $0.title.localizedCaseInsensitiveContains(term) || $0.url.localizedCaseInsensitiveContains(term) }
            case .domainFilter(let domain):
                return historyItems.filter { URL(string: $0.url)?.host == domain }
            }
        }()

        lastQuery = .init(date: Date(), query: query, items: items)
        return items
    }

    private let historyGroupingProvider: HistoryGroupingProvider
    private let historyCoordinator: HistoryCoordinating & HistoryDeleting
    private let dateFormatter: HistoryViewDateFormatting

    /// this is to be optimized: https://app.asana.com/0/72649045549333/1209339909309306
    private var groupings: [HistoryViewGrouping] = []
    private var historyItems: [DataModel.HistoryItem] = []

    private var visitsByRange: [DataModel.HistoryRange: [Visit]] = [:]

    private struct QueryInfo {
        let date: Date
        let query: DataModel.HistoryQueryKind
        let items: [DataModel.HistoryItem]
    }

    private var lastQuery: QueryInfo?
}

extension HistoryView.DataModel.HistoryItem {
    init?(_ visit: Visit, dateFormatter: HistoryViewDateFormatting) {
        guard let historyEntry = visit.historyEntry else {
            return nil
        }
        let title: String = {
            guard let title = historyEntry.title, !title.isEmpty else {
                return historyEntry.url.absoluteString
            }
            return title
        }()
        self.init(
            id: historyEntry.identifier.uuidString,
            url: historyEntry.url.absoluteString,
            title: title,
            domain: historyEntry.url.host ?? historyEntry.url.absoluteString,
            etldPlusOne: historyEntry.etldPlusOne,
            dateRelativeDay: dateFormatter.weekDay(for: visit.date),
            dateShort: "", // not in use at the moment
            dateTimeOfDay: dateFormatter.time(for: visit.date)
        )
    }
}
