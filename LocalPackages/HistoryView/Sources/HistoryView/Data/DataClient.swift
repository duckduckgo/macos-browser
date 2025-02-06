//
//  DataClient.swift
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

import AppKit
import Combine
import Common
import os.log
import UserScriptActionsManager
import WebKit

public enum HistoryViewFilter {
    case all
    case today
    case yesterday
    case twoDaysAgo
    case threeDaysAgo
    case fourDaysAgo
    case fiveOrMoreDaysAgo
    case recentlyClosed
}

public protocol DataProviding: AnyObject {
    var ranges: [DataModel.HistoryRange] { get }

    func visits(for query: DataModel.HistoryQueryKind, limit: UInt, offset: UInt) async -> DataModel.HistoryItemsBatch
}

public final class DataClient: HistoryViewUserScriptClient {

    private var cancellables = Set<AnyCancellable>()
    private let dataProvider: DataProviding

    public init(dataProvider: DataProviding) {
        self.dataProvider = dataProvider
        super.init()
    }

    enum MessageName: String, CaseIterable {
        case getRanges
        case query
    }

    public override func registerMessageHandlers(for userScript: HistoryViewUserScript) {
        userScript.registerMessageHandlers([
            MessageName.getRanges.rawValue: { [weak self] in try await self?.getRanges(params: $0, original: $1) },
            MessageName.query.rawValue: { [weak self] in try await self?.query(params: $0, original: $1) }
        ])
    }

    @MainActor
    private func getRanges(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DataModel.GetRangesResponse(ranges: dataProvider.ranges)
    }

    @MainActor
    private func query(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let query: DataModel.HistoryQuery = DecodableHelper.decode(from: params) else { return nil }

        let batch = await dataProvider.visits(for: query.query, limit: query.limit, offset: query.offset)
        return DataModel.HistoryQueryResponse(info: .init(finished: batch.finished, query: query.query), value: batch.visits)
    }
}
