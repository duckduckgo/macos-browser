//
//  HistoryGroupingProvider.swift
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

import BrowserServicesKit
import Common
import FeatureFlags
import Foundation
import History
import os.log

/**
 * This protocol describes a data source (history provider) for `HistoryGroupingProvider`.
 */
protocol HistoryGroupingDataSource: AnyObject {
    var history: BrowsingHistory? { get }
}

struct HistoryGrouping {
    let date: Date
    let visits: [Visit]
}

extension HistoryCoordinator: HistoryGroupingDataSource {}

/**
 * This class is responsible for grouping history visits for History Menu.
 *
 * When `historyView` feature flag is enabled, visits are deduplicated
 * to only have the latest visit per URL per day.
 */
final class HistoryGroupingProvider {
    private let featureFlagger: FeatureFlagger
    private(set) weak var dataSource: HistoryGroupingDataSource?

    init(dataSource: HistoryGroupingDataSource, featureFlagger: FeatureFlagger = NSApp.delegateTyped.featureFlagger) {
        self.featureFlagger = featureFlagger
        self.dataSource = dataSource
    }

    /**
     * Returns visits for a given day.
     */
    func getRecentVisits(maxCount: Int) -> [Visit] {
        removeDuplicatesIfNeeded(from: getSortedArrayOfVisits())
            .prefix(maxCount)
            .filter { Calendar.current.isDateInToday($0.date) }
    }

    /**
     * Returns history visits bucketed per day.
     */
    func getVisitGroupings(removingDuplicates shouldRemoveDuplicates: Bool = true) -> [HistoryGrouping] {
        Dictionary(grouping: getSortedArrayOfVisits(), by: \.date.startOfDay)
            .map { date, sortedVisits in
                let visits = shouldRemoveDuplicates ? removeDuplicatesIfNeeded(from: sortedVisits) : sortedVisits
                return HistoryGrouping(date: date, visits: visits)
            }
            .sorted { $0.date > $1.date }
    }

    private func removeDuplicatesIfNeeded(from sortedVisits: [Visit]) -> [Visit] {
        // History View introduces visits deduplication to declutter history.
        // We don't want to release it before History View, so we're
        // only deduplicating visits if the feature flag is on.
        guard featureFlagger.isFeatureOn(.historyView) else {
            return sortedVisits
        }
        // It's so simple because visits array is sorted by timestamp, so removing duplicates would
        // remove items with older timestamps (as proven by unit tests).
        return sortedVisits.removingDuplicates(byKey: \.historyEntry?.url)
    }

    private func getSortedArrayOfVisits() -> [Visit] {
        guard let history = dataSource?.history else {
            Logger.general.error("HistoryCoordinator: No history available")
            return []
        }
        return history.flatMap(\.visits).sorted { $0.date > $1.date }
    }
}
