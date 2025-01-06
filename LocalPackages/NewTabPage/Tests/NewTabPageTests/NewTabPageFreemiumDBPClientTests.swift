//
//  NewTabPageFreemiumDBPClientTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Combine
import RemoteMessaging
import XCTest
@testable import NewTabPage

final class NewTabPageFreemiumDBPClientTests: XCTestCase {
    var client: NewTabPageFreemiumDBPClient!
    var provider: CapturingNewTabPageFreemiumDBPBannerProvider!
    var userScript: NewTabPageUserScript!

    override func setUpWithError() throws {
        try super.setUpWithError()
        provider = CapturingNewTabPageFreemiumDBPBannerProvider()
        client = NewTabPageFreemiumDBPClient(provider: provider)
        userScript = NewTabPageUserScript()
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - getData

    func testWhenMessageIsNilThenGetDataReturnsNilMessage() async throws {
        let messageData: NewTabPageDataModel.FreemiumPIRBannerMessageData = try await sendMessage(named: .getData)
        XCTAssertNil(messageData.content)
    }

    func testThatGetDataReturnsMessageIfPresent() async throws {
        provider.bannerMessage = .init(titleText: "sample_title", descriptionText: "sample_description", actionText: "sample_action")
        let messageData: NewTabPageDataModel.FreemiumPIRBannerMessageData = try await sendMessage(named: .getData)
        let message = try XCTUnwrap(messageData.content)
        XCTAssertEqual(message, .init(titleText: "sample_title", descriptionText: "sample_description", actionText: "sample_action"))
    }

    // MARK: - dismiss

    func testThatDismissIsForwardedToProvider() async throws {
        try await sendMessageExpectingNilResponse(named: .dismiss)
        XCTAssertEqual(provider.dismissCallCount, 1)
    }

    // MARK: - action

    func testThatActionIsForwardedToProvider() async throws {
        try await sendMessageExpectingNilResponse(named: .action)
        XCTAssertEqual(provider.actionCallCount, 1)
    }

    // MARK: - Helper functions

    func sendMessage<Response: Encodable>(named methodName: NewTabPageFreemiumDBPClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func sendMessageExpectingNilResponse(named methodName: NewTabPageFreemiumDBPClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
