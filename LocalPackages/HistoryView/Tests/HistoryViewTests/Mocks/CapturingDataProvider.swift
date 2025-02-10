//
//  CapturingDataProvider.swift
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

import HistoryView

final class CapturingDataProvider: DataProviding {
    var ranges: [DataModel.HistoryRange] {
        rangesCallCount += 1
        return _ranges
    }

    func resetCache() {
        resetCacheCallCount += 1
    }

    func visits(for query: DataModel.HistoryQueryKind, limit: Int, offset: Int) async -> DataModel.HistoryItemsBatch {
        visitsCalls.append(.init(query: query, limit: limit, offset: offset))
        return await visits(query, limit, offset)
    }

    // swiftlint:disable:next identifier_name
    var _ranges: [DataModel.HistoryRange] = []
    var rangesCallCount: Int = 0
    var resetCacheCallCount: Int = 0

    var visitsCalls: [VisitsCall] = []
    var visits: (DataModel.HistoryQueryKind, Int, Int) async -> DataModel.HistoryItemsBatch = { _, _, _ in .init(finished: true, visits: []) }

    struct VisitsCall: Equatable {
        let query: DataModel.HistoryQueryKind
        let limit: Int
        let offset: Int
    }
}
