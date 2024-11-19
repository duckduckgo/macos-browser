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
@testable import DuckDuckGo_Privacy_Browser

final class CapturingNewTabPageActiveRemoteMessageProvider: NewTabPageActiveRemoteMessageProviding {
    @Published var remoteMessage: RemoteMessageModel?

    var remoteMessagePublisher: AnyPublisher<RemoteMessaging.RemoteMessageModel?, Never> {
        $remoteMessage.dropFirst().eraseToAnyPublisher()
    }

    func dismissRemoteMessage(with action: RemoteMessageViewModel.ButtonAction?) async {
        dismissCalls.append(action)
    }

    var dismissCalls: [RemoteMessageViewModel.ButtonAction?] = []
}

final class NewTabPageRMFClientTests: XCTestCase {
    var client: NewTabPageRMFClient!
    var remoteMessageProvider: CapturingNewTabPageActiveRemoteMessageProvider!
    var openURLCalls: [URL] = []
    var userScript: NewTabPageUserScript!

    override func setUpWithError() throws {
        try super.setUpWithError()
        openURLCalls = []
        remoteMessageProvider = CapturingNewTabPageActiveRemoteMessageProvider()
        client = NewTabPageRMFClient(
            remoteMessageProvider: remoteMessageProvider,
            openURLHandler: { [weak self] in self?.openURLCalls.append($0) }
        )
        userScript = NewTabPageUserScript()
        client.registerMessageHandlers(for: userScript)
    }

    func testWhenMessageIsNilThenGetDataReturnsNilMessage() async throws {
        let rmfData: NewTabPageUserScript.RMFData = try await sendMessage(named: .rmfGetData)
        XCTAssertNil(rmfData.content)
    }

    // MARK: - getData

    func testThatGetDataReturnsSmallMessageIfPresent() async throws {
        remoteMessageProvider.remoteMessage = .mockSmall(id: "sample_message")
        let rmfData: NewTabPageUserScript.RMFData = try await sendMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .small(.init(id: "sample_message", titleText: "title", descriptionText: "description")))
    }

    func testThatGetDataReturnsMediumMessageIfPresent() async throws {
        remoteMessageProvider.remoteMessage = .mockMedium(id: "sample_message")
        let rmfData: NewTabPageUserScript.RMFData = try await sendMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .medium(.init(id: "sample_message", titleText: "title", descriptionText: "description", icon: .criticalUpdate)))
    }

    func testThatGetDataReturnsBigSingleActionMessageIfPresent() async throws {
        remoteMessageProvider.remoteMessage = .mockBigSingleAction(id: "sample_message", action: .appStore)
        let rmfData: NewTabPageUserScript.RMFData = try await sendMessage(named: .rmfGetData)
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
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .appStore, secondaryAction: .dismiss)
        let rmfData: NewTabPageUserScript.RMFData = try await sendMessage(named: .rmfGetData)
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
        remoteMessageProvider.remoteMessage = .mockSmall(id: "sample_message")

        try await sendMessageExpectingNilResponse(named: .rmfDismiss, parameters: ["id": "sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.close])
    }

    func testWhenMessageIdDoesNotMatchThenDismissHasNoEffect() async throws {
        remoteMessageProvider.remoteMessage = .mockSmall(id: "sample_message")

        try await sendMessageExpectingNilResponse(named: .rmfDismiss, parameters: ["id": "different_sample_message"])
        XCTAssertTrue(remoteMessageProvider.dismissCalls.isEmpty)
    }

    // MARK: - primaryAction

    func testWhenSingleActionMessageThenPrimaryActionSendsActionToProvider() async throws {
        remoteMessageProvider.remoteMessage = .mockBigSingleAction(id: "sample_message", action: .appStore)

        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.action])
    }

    func testWhenTwoActionMessageThenPrimaryActionSendsPrimaryActionToProvider() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .appStore, secondaryAction: .dismiss)

        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.primaryAction])
    }

    func testWhenMessageHasNoButtonThenPrimaryActionHasNoEffect() async throws {
        remoteMessageProvider.remoteMessage = .mockSmall(id: "sample_message")

        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    func testWhenMessageIdDoesNotMatchThenPrimaryActionHasNoEffect() async throws {
        remoteMessageProvider.remoteMessage = .mockSmall(id: "sample_message")

        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "different_sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    func testWhenSingleActionMessageThenPrimaryActionWithAppStoreOpensAppStoreURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigSingleAction(id: "sample_message", action: .appStore)
        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, [.appStore])
    }

    func testWhenSingleActionMessageThenPrimaryActionWithURLOpensURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigSingleAction(id: "sample_message", action: .url(value: "http://example.com"))
        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, ["http://example.com".url!])
    }

    func testWhenSingleActionMessageThenPrimaryActionWithSurveyOpensSurveyURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigSingleAction(id: "sample_message", action: .survey(value: "http://example.com"))
        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, ["http://example.com".url!])
    }

    func testWhenTwoActionMessageThenPrimaryActionWithAppStoreOpensAppStoreURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .appStore, secondaryAction: .dismiss)
        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, [.appStore])
    }

    func testWhenTwoActionMessageThenPrimaryActionWithURLOpensURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .url(value: "http://example.com"), secondaryAction: .dismiss)
        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, ["http://example.com".url!])
    }

    func testWhenTwoActionMessageThenPrimaryActionWithSurveyOpensSurveyURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .survey(value: "http://example.com"), secondaryAction: .dismiss)
        try await sendMessageExpectingNilResponse(named: .rmfPrimaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, ["http://example.com".url!])
    }

    // MARK: - secondaryAction

    func testWhenTwoActionMessageThenSecondaryActionSendsSecondaryActionToProvider() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .dismiss, secondaryAction: .appStore)

        try await sendMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [.secondaryAction])
    }

    func testWhenSingleActionMessageThenSecondaryActionHasNoEffect() async throws {
        remoteMessageProvider.remoteMessage = .mockBigSingleAction(id: "sample_message", action: .appStore)

        try await sendMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    func testWhenMessageHasNoButtonThenSecondaryActionHasNoEffect() async throws {
        remoteMessageProvider.remoteMessage = .mockSmall(id: "sample_message")

        try await sendMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(remoteMessageProvider.dismissCalls, [])
    }

    func testWhenMessageIdDoesNotMatchThenSecondaryActionHasNoEffect() async throws {
        remoteMessageProvider.remoteMessage = .mockSmall(id: "sample_message")

        try await sendMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: ["id": "different_sample_message"])
        XCTAssertTrue(remoteMessageProvider.dismissCalls.isEmpty)
    }

    func testWhenTwoActionMessageThenSecondaryActionWithAppStoreOpensAppStoreURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .dismiss, secondaryAction: .appStore)
        try await sendMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, [.appStore])
    }

    func testWhenTwoActionMessageThenSecondaryActionWithURLOpensURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .appStore, secondaryAction: .url(value: "http://example.com"))
        try await sendMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, ["http://example.com".url!])
    }

    func testWhenTwoActionMessageThenSecondaryActionWithSurveyOpensSurveyURL() async throws {
        remoteMessageProvider.remoteMessage = .mockBigTwoAction(id: "sample_message", primaryAction: .appStore, secondaryAction: .survey(value: "http://example.com"))
        try await sendMessageExpectingNilResponse(named: .rmfSecondaryAction, parameters: ["id": "sample_message"])
        XCTAssertEqual(openURLCalls, ["http://example.com".url!])
    }

    // MARK: - Helper functions

    func sendMessage<Response: Encodable>(named methodName: NewTabPageRMFClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(parameters, .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func sendMessageExpectingNilResponse(named methodName: NewTabPageRMFClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(parameters, .init())
        XCTAssertNil(response, file: file, line: line)
    }
}

fileprivate extension RemoteMessageModel {
    static func mockSmall(id: String) -> RemoteMessageModel {
        .init(
            id: id,
            content: .small(titleText: "title", descriptionText: "description"),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }

    static func mockMedium(id: String) -> RemoteMessageModel {
        .init(
            id: "sample_message",
            content: .medium(titleText: "title", descriptionText: "description", placeholder: .criticalUpdate),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }

    static func mockBigSingleAction(id: String, action: RemoteAction) -> RemoteMessageModel {
        .init(
            id: "sample_message",
            content: .bigSingleAction(
                titleText: "title",
                descriptionText: "description",
                placeholder: .ddgAnnounce,
                primaryActionText: "primary_action",
                primaryAction: action
            ),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }

    static func mockBigTwoAction(id: String, primaryAction: RemoteAction, secondaryAction: RemoteAction) -> RemoteMessageModel {
        .init(
            id: "sample_message",
            content: .bigTwoAction(
                titleText: "title",
                descriptionText: "description",
                placeholder: .ddgAnnounce,
                primaryActionText: "primary_action",
                primaryAction: primaryAction,
                secondaryActionText: "secondary_action",
                secondaryAction: secondaryAction
            ),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
    }
}
