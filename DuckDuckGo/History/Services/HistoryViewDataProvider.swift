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

final class HistoryViewDataProvider: HistoryView.DataProviding {

    init(historyGroupingDataSource: HistoryGroupingDataSource, dateFormatter: HistoryViewDateFormatting = DefaultHistoryViewDateFormatter()) {
        self.dateFormatter = dateFormatter
        historyGroupingProvider = HistoryGroupingProvider(dataSource: historyGroupingDataSource)
    }

    func resetCache() {
        visits = populateVisits()
    }

    private func populateVisits() -> [DataModel.HistoryItem] {
        historyGroupingProvider.getVisitGroupings()
            .flatMap(\.visits)
            .compactMap { DataModel.HistoryItem($0, dateFormatter: dateFormatter) }
    }

    var ranges: [DataModel.HistoryRange] {
        [.all, .today, .yesterday, .tuesday, .monday, .recentlyOpened]
    }

    func visits(for query: HistoryView.DataModel.HistoryQueryKind, limit: Int, offset: Int) async -> HistoryView.DataModel.HistoryItemsBatch {
        guard offset >= 0, limit > 0, offset < visits.count else {
            return .init(finished: true, visits: [])
        }
        var endIndex = offset + limit
        var finished = false
        if endIndex >= visits.count {
            endIndex = visits.count - 1
            finished = true
        }
        return DataModel.HistoryItemsBatch(finished: finished, visits: Array(visits[offset..<endIndex]))
    }

    private let historyGroupingProvider: HistoryGroupingProvider
    private let dateFormatter: HistoryViewDateFormatting

    private var historyGroupings: [HistoryGrouping] = []
    private lazy var visits: [DataModel.HistoryItem] = self.populateVisits()
}

extension HistoryView.DataModel.HistoryItem {
    init?(_ visit: Visit, dateFormatter: HistoryViewDateFormatting) {
        guard let historyEntry = visit.historyEntry else {
            return nil
        }
        self.init(
            id: historyEntry.identifier.uuidString,
            url: historyEntry.url.absoluteString,
            title: historyEntry.title ?? "",
            etldPlusOne: visit.etldPlusOne,
            dateRelativeDay: dateFormatter.weekDay(for: visit.date),
            dateShort: "",
            dateTimeOfDay: dateFormatter.time(for: visit.date)
        )
    }
}

extension Visit {
    private enum Const {
        static let wwwPrefix = "www."
    }

    var etldPlusOne: String? {
        guard let domain = historyEntry?.url.host else {
            return nil
        }
        return ContentBlocking.shared.tld.eTLDplus1(domain)?.dropping(prefix: Const.wwwPrefix)
    }
}
