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
    private var client: NewTabPageFreemiumDBPClient!
    private var provider: CapturingNewTabPageFreemiumDBPBannerProvider!
    private var userScript: NewTabPageUserScript!
    private var messageHelper: MessageHelper<NewTabPageFreemiumDBPClient.MessageName>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        provider = CapturingNewTabPageFreemiumDBPBannerProvider()
        client = NewTabPageFreemiumDBPClient(provider: provider)
        userScript = NewTabPageUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - getData

    func testWhenMessageIsNilThenGetDataReturnsNilMessage() async throws {
        let messageData: NewTabPageDataModel.FreemiumPIRBannerMessageData = try await messageHelper.handleMessage(named: .getData)
        XCTAssertNil(messageData.content)
    }

    func testThatGetDataReturnsMessageIfPresent() async throws {
        provider.bannerMessage = .init(titleText: "sample_title", descriptionText: "sample_description", actionText: "sample_action")
        let messageData: NewTabPageDataModel.FreemiumPIRBannerMessageData = try await messageHelper.handleMessage(named: .getData)
        let message = try XCTUnwrap(messageData.content)
        XCTAssertEqual(message, .init(titleText: "sample_title", descriptionText: "sample_description", actionText: "sample_action"))
    }

    // MARK: - dismiss

    func testThatDismissIsForwardedToProvider() async throws {
        try await messageHelper.handleMessageExpectingNilResponse(named: .dismiss)
        XCTAssertEqual(provider.dismissCallCount, 1)
    }

    // MARK: - action

    func testThatActionIsForwardedToProvider() async throws {
        try await messageHelper.handleMessageExpectingNilResponse(named: .action)
        XCTAssertEqual(provider.actionCallCount, 1)
    }
}
