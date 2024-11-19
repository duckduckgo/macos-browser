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

    func testThatGetDataReturnsSmallMessageIfPresent() async throws {
        remoteMessageProvider.remoteMessage = RemoteMessageModel(
            id: "sample_message",
            content: .small(titleText: "title", descriptionText: "description"),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
        let rmfData: NewTabPageUserScript.RMFData = try await sendMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .small(.init(id: "sample_message", titleText: "title", descriptionText: "description")))
    }

    func testThatGetDataReturnsMediumMessageIfPresent() async throws {
        remoteMessageProvider.remoteMessage = RemoteMessageModel(
            id: "sample_message",
            content: .medium(titleText: "title", descriptionText: "description", placeholder: .criticalUpdate),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
        let rmfData: NewTabPageUserScript.RMFData = try await sendMessage(named: .rmfGetData)
        let message = try XCTUnwrap(rmfData.content)
        XCTAssertEqual(message, .medium(.init(id: "sample_message", titleText: "title", descriptionText: "description", icon: .criticalUpdate)))
    }

    func testThatGetDataReturnsBigSingleActionMessageIfPresent() async throws {
        remoteMessageProvider.remoteMessage = RemoteMessageModel(
            id: "sample_message",
            content: .bigSingleAction(
                titleText: "title",
                descriptionText: "description",
                placeholder: .ddgAnnounce,
                primaryActionText: "primary_action",
                primaryAction: .appStore
            ),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
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
        remoteMessageProvider.remoteMessage = RemoteMessageModel(
            id: "sample_message",
            content: .bigTwoAction(
                titleText: "title",
                descriptionText: "description",
                placeholder: .ddgAnnounce,
                primaryActionText: "primary_action",
                primaryAction: .appStore,
                secondaryActionText: "secondary_action",
                secondaryAction: .dismiss
            ),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: true
        )
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

    // MARK: - Helper functions

    func sendMessage<Response: Encodable>(named methodName: NewTabPageRMFClient.MessageName, file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler([], .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func sendMessageExpectingNilResponse(named methodName: NewTabPageRMFClient.MessageName, file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler([], .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
