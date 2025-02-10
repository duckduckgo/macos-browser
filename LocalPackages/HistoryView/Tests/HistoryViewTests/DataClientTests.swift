//
//  DataClientTests.swift
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

import XCTest
@testable import HistoryView

final class DataClientTests: XCTestCase {
    private var client: DataClient!
    private var dataProvider: CapturingDataProvider!
    private var actionsHandler: CapturingActionsHandler!
    private var errorHandler: CapturingErrorHandler!
    private var userScript: HistoryViewUserScript!
    private var messageHelper: MessageHelper<DataClient.MessageName>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dataProvider = CapturingDataProvider()
        actionsHandler = CapturingActionsHandler()
        errorHandler = CapturingErrorHandler()
        client = DataClient(dataProvider: dataProvider, actionsHandler: actionsHandler, errorHandler: errorHandler)

        userScript = HistoryViewUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - initialSetup

    func testThatInitialSetupReturnsConfiguration() async throws {
        let configuration: DataModel.Configuration = try await messageHelper.handleMessage(named: .initialSetup)
        XCTAssertEqual(configuration.platform, .init(name: "macos"))
    }

    func testThatInitialSetupResetsDataProviderCache() async throws {
        try await messageHelper.handleMessageIgnoringResponse(named: .initialSetup)
        XCTAssertEqual(dataProvider.resetCacheCallCount, 1)
    }

    // MARK: - getRanges

    func testThatGetRangesReturnsRangesFromDataProvider() async throws {
        dataProvider._ranges = [.all, .friday, .recentlyOpened]
        let rangesResponse: DataModel.GetRangesResponse = try await messageHelper.handleMessage(named: .getRanges)
        XCTAssertEqual(dataProvider.rangesCallCount, 1)
        XCTAssertEqual(rangesResponse.ranges, [.all, .friday, .recentlyOpened])
    }

    // MARK: - query

    func testThatQueryReturnsDataFromProviderAndEchoesQueryKind() async throws {
        let historyItem = DataModel.HistoryItem(id: "1", url: "https://example.com", title: "Example.com", domain: "example.com", etldPlusOne: "example.com", dateRelativeDay: "Today", dateShort: "", dateTimeOfDay: "10:08")
        dataProvider.visits = { _, _, _ in return .init(finished: true, visits: [historyItem]) }
        let query = DataModel.HistoryQuery(query: .searchTerm(""), limit: 150, offset: 0)

        let queryResponse: DataModel.HistoryQueryResponse = try await messageHelper.handleMessage(named: .query, parameters: query)
        XCTAssertEqual(dataProvider.visitsCalls.count, 1)
        XCTAssertEqual(queryResponse, .init(info: .init(finished: true, query: query.query), value: [historyItem]))
    }

    // MARK: - open

    func testThatOpenCallsActionHandler() async throws {
        let url = "https://example.com"
        try await messageHelper.handleMessageExpectingNilResponse(named: .open, parameters: DataModel.HistoryOpenAction(url: url))
        XCTAssertEqual(actionsHandler.openCalls, [try XCTUnwrap(URL(string: url))])
    }

    // MARK: - reportInitException

    func testThatReportInitExceptionForwardsEventToTheMapper() async throws {
        let exception = DataModel.Exception(message: "sample message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .reportInitException, parameters: exception)

        XCTAssertEqual(errorHandler.events, [.historyViewError(message: "sample message")])
    }

    // MARK: - reportPageException

    func testThatReportPageExceptionForwardsEventToTheMapper() async throws {
        let exception = DataModel.Exception(message: "sample message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .reportPageException, parameters: exception)

        XCTAssertEqual(errorHandler.events, [.historyViewError(message: "sample message")])
    }
}
