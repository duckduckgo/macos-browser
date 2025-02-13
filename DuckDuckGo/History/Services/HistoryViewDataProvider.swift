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

protocol HistoryViewDateFormatting {
    func weekDay(for date: Date) -> String
    func time(for date: Date) -> String
}

struct DefaultHistoryViewDateFormatter: HistoryViewDateFormatting {
    let weekDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "cccc"
        return formatter
    }()

    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    func weekDay(for date: Date) -> String {
        weekDayFormatter.string(from: date)
    }

    func time(for date: Date) -> String {
        timeFormatter.string(from: date)
    }
}

struct HistoryViewGrouping {
    let range: DataModel.HistoryRange
    let visits: [DataModel.HistoryItem]

    init(range: DataModel.HistoryRange, visits: [DataModel.HistoryItem]) {
        self.range = range
        self.visits = visits
    }

    init?(_ historyGrouping: HistoryGrouping, dateFormatter: HistoryViewDateFormatting) {
        guard let range = DataModel.HistoryRange(date: historyGrouping.date, referenceDate: Date()) else {
            return nil
        }
        self.range = range
        visits = historyGrouping.visits.compactMap { DataModel.HistoryItem($0, dateFormatter: dateFormatter) }
    }
}

final class HistoryViewDataProvider: HistoryView.DataProviding {

    init(historyGroupingDataSource: HistoryGroupingDataSource, dateFormatter: HistoryViewDateFormatting = DefaultHistoryViewDateFormatter()) {
        self.dateFormatter = dateFormatter
        historyGroupingProvider = HistoryGroupingProvider(dataSource: historyGroupingDataSource)
    }

    func resetCache() {
        lastQuery = nil
        populateVisits()
    }

    private func populateVisits() {
        var groupings = historyGroupingProvider.getVisitGroupings()
            .compactMap { HistoryViewGrouping($0, dateFormatter: dateFormatter) }
        var olderVisits = [DataModel.HistoryItem]()

        groupings = groupings.filter { grouping in
            guard grouping.range != .older else {
                olderVisits.append(contentsOf: grouping.visits)
                return false
            }
            return true
        }

        if !olderVisits.isEmpty {
            groupings.append(.init(range: .older, visits: olderVisits))
        }

        self.groupings = groupings
        self.visits = groupings.flatMap(\.visits)
    }

    var ranges: [DataModel.HistoryRange] {
        var ranges: [DataModel.HistoryRange] = [.all]
        ranges.append(contentsOf: groupings.map(\.range))
        // to be implemented
//        ranges.append(.recentlyOpened)
        return ranges
    }

    func visits(for query: DataModel.HistoryQueryKind, limit: Int, offset: Int) async -> HistoryView.DataModel.HistoryItemsBatch {
        let items = perform(query)
        let visits = items.chunk(with: limit, offset: offset)
        let finished = items.count < limit
        return DataModel.HistoryItemsBatch(finished: finished, visits: visits)
    }

    private func perform(_ query: DataModel.HistoryQueryKind) -> [DataModel.HistoryItem] {
        if let lastQuery, lastQuery.query == query {
            return lastQuery.items
        }

        let items: [DataModel.HistoryItem] = {
            switch query {
            case .rangeFilter(.recentlyOpened):
                return [] // to be implemented
            case .rangeFilter(.all), .searchTerm(""):
                return visits
            case .rangeFilter(let range):
                return groupings.first(where: { $0.range == range })?.visits ?? []
            case .searchTerm(let term):
                return visits.filter { $0.title.localizedCaseInsensitiveContains(term) || $0.url.localizedCaseInsensitiveContains(term) }
            case .domainFilter(let domain):
                return visits.filter { URL(string: $0.url)?.host == domain }
            }
        }()

        lastQuery = .init(query: query, items: items)
        return items
    }

    private let historyGroupingProvider: HistoryGroupingProvider
    private let dateFormatter: HistoryViewDateFormatting

    /// this is to be optimized: https://app.asana.com/0/72649045549333/1209339909309306
    private var groupings: [HistoryViewGrouping] = []
    private var visits: [DataModel.HistoryItem] = []

    private struct QueryInfo {
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
}
