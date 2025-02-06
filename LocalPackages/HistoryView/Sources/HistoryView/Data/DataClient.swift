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
    func visits(for query: String?, filter: HistoryViewFilter, pageSize: UInt, offset: UInt) async -> [DataModel.HistoryItem]
}

public final class DataClient: HistoryViewUserScriptClient {

    private var cancellables = Set<AnyCancellable>()
    private let dataProvider: DataProviding

    public init(dataProvider: DataProviding) {
        self.dataProvider = dataProvider
        super.init()
    }

    enum MessageName: String, CaseIterable {
        case query
    }

    public override func registerMessageHandlers(for userScript: HistoryViewUserScript) {
        userScript.registerMessageHandlers([
            MessageName.query.rawValue: { [weak self] in try await self?.query(params: $0, original: $1) }
        ])
    }

    @MainActor
    private func query(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let query: DataModel.Query = DecodableHelper.decode(from: params) else { return nil }

        /// This is a placeholder implementation, to be updated.
        return DataModel.QueryResponse(
            info: .init(finished: true, term: query.term),
            value: [
                .init(dateRelativeDay: "Today", dateShort: "Jan 16, 2025", dateTimeOfDay: "13:59", domain: "example.com", fallbackFaviconText: "ex", time: Date().timeIntervalSince1970, title: "Example com", url: "https://example.com")
            ])
    }
}
