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
        let history = await Task { @MainActor in
            self.historyCoordinator.history
        }.value
        guard let history else {
            return
        }
        let date = lastQuery?.date ?? Date()
        let visits: [Visit] = {
            let allVisits: [Visit] = history.flatMap(\.visits)
            guard let dateRange = range.dateRange(for: date) else {
                return allVisits
            }
            return allVisits.filter { dateRange.contains($0.date) }
        }()

        await historyCoordinator.delete(visits)
        await resetCache()
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

extension HistoryView.DataModel.HistoryRange {

    /**
     * Initializes HistoryRange based on `date`s proximity to `referenceDate`.
     *
     * Possible values are:
     * - `today`,
     * - `yesterday`,
     * - week day name for 2-4 days ago,
     * - `older`.
     * - `nil` when `date` is newer than `referenceDate` (which shouldn't happen).
     */
    init?(date: Date, referenceDate: Date) {
        guard referenceDate > date else {
            return nil
        }
        let calendar = Calendar.autoupdatingCurrent
        let numberOfDaysSinceReferenceDate = calendar.numberOfDaysBetween(date, and: referenceDate)

        switch numberOfDaysSinceReferenceDate {
        case 0:
            self = .today
            return
        case 1:
            self = .yesterday
            return
        default:
            break
        }

        let referenceWeekday = calendar.component(.weekday, from: referenceDate)
        let twoDaysAgo = referenceWeekday > 2 ? referenceWeekday - 2 : referenceWeekday + 5
        let threeDaysAgo = referenceWeekday > 3 ? referenceWeekday - 3 : referenceWeekday + 4
        let fourDaysAgo = referenceWeekday > 4 ? referenceWeekday - 4 : referenceWeekday + 3

        let weekday = calendar.component(.weekday, from: date)
        if [twoDaysAgo, threeDaysAgo, fourDaysAgo].contains(weekday),
           let numberOfDaysSinceReferenceDate, numberOfDaysSinceReferenceDate <= 4,
           let range = DataModel.HistoryRange(weekday: weekday) {

            self = range
        } else {
            self = .older
        }
    }

    init?(weekday: Int) {
        switch weekday {
        case 1:
            self = .sunday
        case 2:
            self = .monday
        case 3:
            self = .tuesday
        case 4:
            self = .wednesday
        case 5:
            self = .thursday
        case 6:
            self = .friday
        case 7:
            self = .saturday
        default:
            return nil
        }
    }

    func weekday(for referenceDate: Date) -> Int? {
        let calendar = Calendar.autoupdatingCurrent
        let referenceWeekday = calendar.component(.weekday, from: referenceDate)

        switch self {
        case .all:
            return nil
        case .today:
            return referenceWeekday
        case .yesterday:
            return referenceWeekday == 1 ? 7 : referenceWeekday-1
        case .sunday:
            return 1
        case .monday:
            return 2
        case .tuesday:
            return 3
        case .wednesday:
            return 4
        case .thursday:
            return 5
        case .friday:
            return 6
        case .saturday:
            return 7
        case .older:
            let weekday = referenceWeekday - 5
            return weekday > 0 ? weekday : weekday+7
        }
    }

    func dateRange(for referenceDate: Date) -> Range<Date>? {
        guard let weekday = weekday(for: referenceDate) else { // this covers .all range
            return nil
        }

        let calendar = Calendar.autoupdatingCurrent
        let startOfDayReferenceDate = referenceDate.startOfDay
        let date = calendar.firstWeekday(weekday, before: startOfDayReferenceDate)
        let nextDay = date.daysAgo(-1)

        if self == .older {
            return Date.distantPast..<nextDay
        }
        return date..<nextDay
    }
}

extension Calendar {
    public func firstWeekday(_ weekday: Int, before referenceDate: Date) -> Date {
        let referenceWeekday = component(.weekday, from: referenceDate)
        let daysDiff: Int = {
            switch (weekday, referenceWeekday) {
            case let (a, b) where a < b:
                return b - a
            case let (a, b) where a > b:
                return b - a + 7
            default: // same weekday
                return 7
            }
        }()
        return referenceDate.daysAgo(daysDiff)
    }

}
