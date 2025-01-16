//
//  NewTabPageRMFClientTests.swift
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

final class NewTabPageRMFClientTests: XCTestCase {
    private var client: NewTabPageRMFClient!
    private var remoteMessageProvider: CapturingNewTabPageActiveRemoteMessageProvider!
    private var userScript: NewTabPageUserScript!
    private var messageHelper: MessageHelper<NewTabPageRMFClient.MessageName>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        remoteMessageProvider = CapturingNewTabPageActiveRemoteMessageProvider()
        client = NewTabPageRMFClient(remoteMessageProvider: remoteMessageProvider)
        userScript = NewTabPageUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)
    }

    func testWhenMessageIsNilThenGetDataReturnsNilMessage() async throws {
        let rmfData: NewTabPageDataModel.RMFData = try await messageHelper.handleMessage(named: .rmfGetData)
        XCTAssertNil(rmfData.content)
    }

    // MARK: - getData

    func testThatGetDataReturnsSmallMessageIfPresent() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockSmall(id: "sample_message")
        let rmfData: NewTabPageDataModel.RMFData = try await messageHelper.handleMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .small(.init(id: "sample_message", titleText: "title", descriptionText: "description")))
    }

    func testThatGetDataReturnsMediumMessageIfPresent() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockMedium(id: "sample_message")
        let rmfData: NewTabPageDataModel.RMFData = try await messageHelper.handleMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .medium(.init(id: "sample_message", titleText: "title", descriptionText: "description", icon: .criticalUpdate)))
    }

    func testThatGetDataReturnsBigSingleActionMessageIfPresent() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockBigSingleAction(id: "sample_message", action: .appStore)
        let rmfData: NewTabPageDataModel.RMFData = try await messageHelper.handleMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .bigSingleAction(
            .init(
                id: "sample_message",
                titleText: "title",
                descriptionText: "description",
                icon: .ddgAnnounce,
                primaryActionText: "primary_action"
            )
        ))
    }

    func testThatGetDataReturnsBigTwoActionMessageIfPresent() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .appStore, secondaryAction: .dismiss)
        let rmfData: NewTabPageDataModel.RMFData = try await messageHelper.handleMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .bigTwoAction(
            .init(
                id: "sample_message",
                titleText: "title",
                descriptionText: "description",
                icon: .ddgAnnounce,
                primaryActionText: "primary_action",
                secondaryActionText: "secondary_action"
            )
        ))
    }

    // MARK: - dismiss

    func testThatDismissSendsDismissActionToProvider() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockSmall(id: "sample_message")

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfDismiss, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.init(action: nil, button: .close)])
    }

    func testWhenMessageIdDoesNotMatchThenDismissHasNoEffect() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockSmall(id: "sample_message")

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "different_sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfDismiss, parameters: parameters)
        XCTAssertTrue(remoteMessageProvider.dismissCalls.isEmpty)
    }

    // MARK: - primaryAction

    func testWhenSingleActionMessageThenPrimaryActionSendsActionToProvider() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockBigSingleAction(id: "sample_message", action: .appStore)

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.init(action: .appStore, button: .action)])
    }

    func testWhenTwoActionMessageThenPrimaryActionSendsPrimaryActionToProvider() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .appStore, secondaryAction: .dismiss)

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.init(action: .appStore, button: .primaryAction)])
    }

    func testWhenMessageHasNoButtonThenPrimaryActionHasNoEffect() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockSmall(id: "sample_message")

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    func testWhenMessageIdDoesNotMatchThenPrimaryActionHasNoEffect() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockSmall(id: "sample_message")

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "different_sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    // MARK: - secondaryAction

    func testWhenTwoActionMessageThenSecondaryActionSendsSecondaryActionToProvider() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .dismiss, secondaryAction: .appStore)

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.init(action: .appStore, button: .secondaryAction)])
    }

    func testWhenSingleActionMessageThenSecondaryActionHasNoEffect() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockBigSingleAction(id: "sample_message", action: .appStore)

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    func testWhenMessageHasNoButtonThenSecondaryActionHasNoEffect() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockSmall(id: "sample_message")

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    func testWhenMessageIdDoesNotMatchThenSecondaryActionHasNoEffect() async throws {
        remoteMessageProvider.newTabPageRemoteMessage = .mockSmall(id: "sample_message")

        let parameters = NewTabPageDataModel.RemoteMessageParams(id: "different_sample_message")
        try await messageHelper.handleMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: parameters)
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }
}
