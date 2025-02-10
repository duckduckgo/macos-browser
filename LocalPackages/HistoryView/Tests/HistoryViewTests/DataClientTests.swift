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
