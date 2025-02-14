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
    func resetCache() async
    func visits(for query: DataModel.HistoryQueryKind, limit: Int, offset: Int) async -> DataModel.HistoryItemsBatch
    func deleteVisits(for range: DataModel.HistoryRange) async
}

public enum HistoryViewEvent: Equatable {
    case historyViewError(message: String)
}

public final class DataClient: HistoryViewUserScriptClient {

    private var cancellables = Set<AnyCancellable>()
    private let dataProvider: DataProviding
    private let actionsHandler: ActionsHandling
    private let errorHandler: EventMapping<HistoryViewEvent>?

    public init(dataProvider: DataProviding, actionsHandler: ActionsHandling, errorHandler: EventMapping<HistoryViewEvent>?) {
        self.dataProvider = dataProvider
        self.actionsHandler = actionsHandler
        self.errorHandler = errorHandler
        super.init()
    }

    enum MessageName: String, CaseIterable {
        case initialSetup
        case getRanges
        case deleteRange
        case open
        case query
        case titleMenu = "title_menu"
        case entriesMenu = "entries_menu"
        case reportInitException
        case reportPageException
    }

    public override func registerMessageHandlers(for userScript: HistoryViewUserScript) {
        userScript.registerMessageHandlers([
            MessageName.initialSetup.rawValue: { [weak self] in try await self?.initialSetup(params: $0, original: $1) },
            MessageName.getRanges.rawValue: { [weak self] in try await self?.getRanges(params: $0, original: $1) },
            MessageName.deleteRange.rawValue: { [weak self] in try await self?.deleteRange(params: $0, original: $1) },
            MessageName.query.rawValue: { [weak self] in try await self?.query(params: $0, original: $1) },
            MessageName.open.rawValue: { [weak self] in try await self?.open(params: $0, original: $1) },
            MessageName.titleMenu.rawValue: { [weak self] in try await self?.titleMenu(params: $0, original: $1) },
            MessageName.entriesMenu.rawValue: { [weak self] in try await self?.entriesMenu(params: $0, original: $1) },
            MessageName.reportInitException.rawValue: { [weak self] in try await self?.reportException(params: $0, original: $1) },
            MessageName.reportPageException.rawValue: { [weak self] in try await self?.reportException(params: $0, original: $1) },
        ])
    }

    @MainActor
    private func initialSetup(params: Any, original: WKScriptMessage) async throws -> Encodable? {
#if DEBUG || REVIEW
        let env = "development"
#else
        let env = "production"
#endif

        await dataProvider.resetCache()

        return DataModel.Configuration(
            env: env,
            locale: Bundle.main.preferredLocalizations.first ?? "en",
            platform: .init(name: "macos")
        )
    }

    @MainActor
    private func getRanges(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        DataModel.GetRangesResponse(ranges: dataProvider.ranges)
    }

    @MainActor
    private func deleteRange(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let request: DataModel.DeleteRangeRequest = DecodableHelper.decode(from: params) else { return nil }
        let action = await actionsHandler.showDeleteDialog(for: request.range)
        return DataModel.DeleteRangeResponse(action: action)
    }

    @MainActor
    private func query(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let query: DataModel.HistoryQuery = DecodableHelper.decode(from: params) else { return nil }

        let batch = await dataProvider.visits(for: query.query, limit: query.limit, offset: query.offset)
        return DataModel.HistoryQueryResponse(info: .init(finished: batch.finished, query: query.query), value: batch.visits)
    }

    @MainActor
    private func open(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let action: DataModel.HistoryOpenAction = DecodableHelper.decode(from: params) else {
            return nil
        }
        guard let url = URL(string: action.url), url.isValid else { return nil }
        actionsHandler.open(url)
        return nil
    }

    @MainActor
    private func titleMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return nil
    }

    @MainActor
    private func entriesMenu(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return nil
    }

    private func reportException(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let exception: DataModel.Exception = DecodableHelper.decode(from: params) else {
            return nil
        }
        errorHandler?.fire(.historyViewError(message: exception.message))
        Logger.general.error("History View error: \("\(exception.message)", privacy: .public)")
        return nil
    }
}
