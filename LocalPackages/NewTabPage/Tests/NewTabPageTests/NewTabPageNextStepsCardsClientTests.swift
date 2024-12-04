//
//  NewTabPageNextStepsCardsClientTests.swift
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
import TestUtils
import XCTest
@testable import NewTabPage

final class CapturingNewTabPageNextStepsCardsProvider: NewTabPageNextStepsCardsProviding {

    @Published var isViewExpanded: Bool = false
    var isViewExpandedPublisher: AnyPublisher<Bool, Never> {
        $isViewExpanded.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    @Published var cards: [NewTabPageNextStepsCardsClient.CardID] = []
    var cardsPublisher: AnyPublisher<[NewTabPageNextStepsCardsClient.CardID], Never> {
        $cards.dropFirst().removeDuplicates().eraseToAnyPublisher()
    }

    func handleAction(for card: NewTabPageNextStepsCardsClient.CardID) {
        handleActionCalls.append(card)
    }

    func dismiss(_ card: NewTabPageNextStepsCardsClient.CardID) {
        dismissCalls.append(card)
    }

    func willDisplayCards(_ cards: [NewTabPageNextStepsCardsClient.CardID]) {
        willDisplayCardsCalls.append(cards)
        willDisplayCardsImpl?(cards)
    }

    var handleActionCalls: [NewTabPageNextStepsCardsClient.CardID] = []
    var dismissCalls: [NewTabPageNextStepsCardsClient.CardID] = []
    var willDisplayCardsCalls: [[NewTabPageNextStepsCardsClient.CardID]] = []
    var willDisplayCardsImpl: (([NewTabPageNextStepsCardsClient.CardID]) -> Void)?
}

final class NewTabPageNextStepsCardsClientTests: XCTestCase {
    var client: NewTabPageNextStepsCardsClient!
    var model: CapturingNewTabPageNextStepsCardsProvider!
    var userScript: NewTabPageUserScript!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        model = CapturingNewTabPageNextStepsCardsProvider()
        client = NewTabPageNextStepsCardsClient(model: model)

        userScript = NewTabPageUserScript()
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - action

    func testThatActionCallsHandleAction() async throws {
        try await handleMessageExpectingNilResponse(named: .action, parameters: NewTabPageNextStepsCardsClient.Card(id: .defaultApp))
        try await handleMessageExpectingNilResponse(named: .action, parameters: NewTabPageNextStepsCardsClient.Card(id: .duckplayer))
        try await handleMessageExpectingNilResponse(named: .action, parameters: NewTabPageNextStepsCardsClient.Card(id: .bringStuff))
        XCTAssertEqual(model.handleActionCalls, [.defaultApp, .duckplayer, .bringStuff])
    }

    // MARK: - dismiss

    func testThatDismissCallsDismissHandler() async throws {
        try await handleMessageExpectingNilResponse(named: .dismiss, parameters: NewTabPageNextStepsCardsClient.Card(id: .defaultApp))
        try await handleMessageExpectingNilResponse(named: .dismiss, parameters: NewTabPageNextStepsCardsClient.Card(id: .duckplayer))
        try await handleMessageExpectingNilResponse(named: .dismiss, parameters: NewTabPageNextStepsCardsClient.Card(id: .bringStuff))
        XCTAssertEqual(model.dismissCalls, [.defaultApp, .duckplayer, .bringStuff])
    }

    // MARK: - getConfig

    func testWhenNextStepsViewIsExpandedThenGetConfigReturnsExpandedState() async throws {
        model.isViewExpanded = true
        let config: NewTabPageUserScript.WidgetConfig = try await handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .auto)
        XCTAssertEqual(config.expansion, .expanded)
    }

    func testWhenNextStepsViewIsCollapsedThenGetConfigReturnsCollapsedState() async throws {
        model.isViewExpanded = false
        let config: NewTabPageUserScript.WidgetConfig = try await handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .auto)
        XCTAssertEqual(config.expansion, .collapsed)
    }

    // MARK: - setConfig

    func testWhenSetConfigContainsExpandedStateThenModelSettingIsSetToExpanded() async throws {
        model.isViewExpanded = false
        let config = NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: .expanded)
        try await handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(model.isViewExpanded, true)
    }

    func testWhenSetConfigContainsCollapsedStateThenModelSettingIsSetToCollapsed() async throws {
        model.isViewExpanded = true
        let config = NewTabPageUserScript.WidgetConfig(animation: .auto, expansion: .collapsed)
        try await handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(model.isViewExpanded, false)
    }

    // MARK: - getData

    func testThatGetDataReturnsCardsFromTheModel() async throws {
        model.cards = [
            .addAppToDockMac,
            .duckplayer,
            .bringStuff
        ]
        let data: NewTabPageNextStepsCardsClient.NextStepsData = try await handleMessage(named: .getData)
        XCTAssertEqual(data, .init(content: [
            .init(id: .addAppToDockMac),
            .init(id: .duckplayer),
            .init(id: .bringStuff)
        ]))
    }

    func testWhenCardsAreEmptyThenGetDataReturnsNilContent() async throws {
        model.cards = []
        let data: NewTabPageNextStepsCardsClient.NextStepsData = try await handleMessage(named: .getData)
        XCTAssertEqual(data, .init(content: nil))
    }

    // MARK: - willDisplayCardsPublisher

    func testThatWillDisplayCardsPublisherIsSentAfterGetDataAndGetConfigAreCalled() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        _ = try await client.getData(params: [], original: .init())
        _ = try await client.getConfig(params: [], original: .init())

        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer]])
    }

    func testThatWillDisplayCardsPublisherIsNotSentBeforeGetConfigIsCalled() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        _ = try await client.getData(params: [], original: .init())
        _ = try await client.getData(params: [], original: .init())
        _ = try await client.getData(params: [], original: .init())
        _ = try await client.getData(params: [], original: .init())
        _ = try await client.getData(params: [], original: .init())

        XCTAssertEqual(model.willDisplayCardsCalls, [])

        _ = try await client.getConfig(params: [], original: .init())

        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer]])
    }

    func testThatWillDisplayCardsPublisherIsNotSentBeforeGetDataIsCalled() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        _ = try await client.getConfig(params: [], original: .init())
        _ = try await client.getConfig(params: [], original: .init())
        _ = try await client.getConfig(params: [], original: .init())
        _ = try await client.getConfig(params: [], original: .init())
        _ = try await client.getConfig(params: [], original: .init())

        XCTAssertEqual(model.willDisplayCardsCalls, [])

        _ = try await client.getData(params: [], original: .init())

        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer]])
    }

    func testThatWillDisplayCardsPublisherIsSentAfterUpdatingCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        model.isViewExpanded = true
        try await triggerInitialCardsEventAndResetMockState()

        let expectation = self.expectation(description: "willDisplayCards")
        model.willDisplayCardsImpl = { _ in expectation.fulfill() }

        model.cards = [.addAppToDockMac, .duckplayer, .bringStuff]
        await fulfillment(of: [expectation], timeout: 0.1)
        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer, .bringStuff]])
    }

    func testWhenCardsAreUpdatedThenWillDisplayCardsEventOnlyContainsCurrentlyVisibleCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        model.isViewExpanded = false
        try await triggerInitialCardsEventAndResetMockState()

        let expectation = self.expectation(description: "willDisplayCards")
        expectation.expectedFulfillmentCount = 3
        model.willDisplayCardsImpl = { _ in expectation.fulfill() }

        model.cards = [.addAppToDockMac, .duckplayer, .bringStuff]
        model.cards = [.duckplayer, .addAppToDockMac, .bringStuff]
        model.cards = [.addAppToDockMac, .emailProtection, .duckplayer]
        await fulfillment(of: [expectation], timeout: 0.1)
        XCTAssertEqual(model.willDisplayCardsCalls, [
            [.addAppToDockMac, .duckplayer],
            [.duckplayer, .addAppToDockMac],
            [.addAppToDockMac, .emailProtection]
        ])
    }

    func testThatWillDisplayCardsEventIsNotPublishedWhenCardsIsEmpty() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        model.isViewExpanded = false
        try await triggerInitialCardsEventAndResetMockState()

        let expectation = self.expectation(description: "willDisplayCards")
        expectation.expectedFulfillmentCount = 2
        model.willDisplayCardsImpl = { _ in expectation.fulfill() }

        model.cards = [.addAppToDockMac, .duckplayer, .bringStuff]
        model.cards = []
        model.cards = [.addAppToDockMac, .emailProtection, .duckplayer]
        await fulfillment(of: [expectation], timeout: 0.1)
        XCTAssertEqual(model.willDisplayCardsCalls, [
            [.addAppToDockMac, .duckplayer],
            [.addAppToDockMac, .emailProtection]
        ])
    }

    func testThatWillDisplayCardsPublisherIsSentAfterExpandingViewToRevealMoreCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer, .emailProtection, .bringStuff, .defaultApp]
        model.isViewExpanded = false
        try await triggerInitialCardsEventAndResetMockState()

        let expectation = self.expectation(description: "willDisplayCards")
        model.willDisplayCardsImpl = { _ in expectation.fulfill() }

        model.isViewExpanded = true
        await fulfillment(of: [expectation], timeout: 0.1)
        XCTAssertEqual(model.willDisplayCardsCalls, [[.emailProtection, .bringStuff, .defaultApp]])
    }

    func testThatWillDisplayCardsPublisherIsSentAfterExpandingViewAndNotRevealingMoreCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        model.isViewExpanded = false
        try await triggerInitialCardsEventAndResetMockState()

        let expectation = self.expectation(description: "willDisplayCards")
        expectation.isInverted = true
        model.willDisplayCardsImpl = { _ in expectation.fulfill() }

        model.isViewExpanded = true
        await fulfillment(of: [expectation], timeout: 0.1)
        XCTAssertEqual(model.willDisplayCardsCalls, [])
    }

    func testThatWillDisplayCardsPublisherIsNotSentAfterCollapsingView() async throws {
        model.cards = [.addAppToDockMac, .duckplayer, .emailProtection]
        model.isViewExpanded = true
        try await triggerInitialCardsEventAndResetMockState()

        let expectation = self.expectation(description: "willDisplayCards")
        expectation.isInverted = true
        model.willDisplayCardsImpl = { _ in expectation.fulfill() }

        model.isViewExpanded = false
        await fulfillment(of: [expectation], timeout: 0.1)
        XCTAssertEqual(model.willDisplayCardsCalls, [])
    }

    // MARK: - Helper functions

    func triggerInitialCardsEventAndResetMockState() async throws {
        _ = try await client.getConfig(params: [], original: .init())
        _ = try await client.getData(params: [], original: .init())
        model.willDisplayCardsCalls = []
    }

    func handleMessage<Response: Encodable>(named methodName: NewTabPageNextStepsCardsClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws -> Response {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        return try XCTUnwrap(response as? Response, file: file, line: line)
    }

    func handleMessageExpectingNilResponse(named methodName: NewTabPageNextStepsCardsClient.MessageName, parameters: Any = [], file: StaticString = #file, line: UInt = #line) async throws {
        let handler = try XCTUnwrap(userScript.handler(forMethodNamed: methodName.rawValue), file: file, line: line)
        let response = try await handler(NewTabPageTestsHelper.asJSON(parameters), .init())
        XCTAssertNil(response, file: file, line: line)
    }
}
