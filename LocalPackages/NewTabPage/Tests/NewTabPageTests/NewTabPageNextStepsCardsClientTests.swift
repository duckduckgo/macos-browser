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
import PersistenceTestingUtils
import XCTest
@testable import NewTabPage

final class NewTabPageNextStepsCardsClientTests: XCTestCase {
    private var client: NewTabPageNextStepsCardsClient!
    private var model: CapturingNewTabPageNextStepsCardsProvider!
    private var userScript: NewTabPageUserScript!
    private var messageHelper: MessageHelper<NewTabPageNextStepsCardsClient.MessageName>!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        model = CapturingNewTabPageNextStepsCardsProvider()
        client = NewTabPageNextStepsCardsClient(model: model)

        userScript = NewTabPageUserScript()
        messageHelper = .init(userScript: userScript)
        client.registerMessageHandlers(for: userScript)
    }

    // MARK: - action

    func testThatActionCallsHandleAction() async throws {
        try await messageHelper.handleMessageExpectingNilResponse(named: .action, parameters: NewTabPageDataModel.Card(id: .defaultApp))
        try await messageHelper.handleMessageExpectingNilResponse(named: .action, parameters: NewTabPageDataModel.Card(id: .duckplayer))
        try await messageHelper.handleMessageExpectingNilResponse(named: .action, parameters: NewTabPageDataModel.Card(id: .bringStuff))
        XCTAssertEqual(model.handleActionCalls, [.defaultApp, .duckplayer, .bringStuff])
    }

    // MARK: - dismiss

    func testThatDismissCallsDismissHandler() async throws {
        try await messageHelper.handleMessageExpectingNilResponse(named: .dismiss, parameters: NewTabPageDataModel.Card(id: .defaultApp))
        try await messageHelper.handleMessageExpectingNilResponse(named: .dismiss, parameters: NewTabPageDataModel.Card(id: .duckplayer))
        try await messageHelper.handleMessageExpectingNilResponse(named: .dismiss, parameters: NewTabPageDataModel.Card(id: .bringStuff))
        XCTAssertEqual(model.dismissCalls, [.defaultApp, .duckplayer, .bringStuff])
    }

    // MARK: - getConfig

    func testWhenNextStepsViewIsExpandedThenGetConfigReturnsExpandedState() async throws {
        model.isViewExpanded = true
        let config: NewTabPageUserScript.WidgetConfig = try await messageHelper.handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .noAnimation)
        XCTAssertEqual(config.expansion, .expanded)
    }

    func testWhenNextStepsViewIsCollapsedThenGetConfigReturnsCollapsedState() async throws {
        model.isViewExpanded = false
        let config: NewTabPageUserScript.WidgetConfig = try await messageHelper.handleMessage(named: .getConfig)
        XCTAssertEqual(config.animation, .noAnimation)
        XCTAssertEqual(config.expansion, .collapsed)
    }

    // MARK: - setConfig

    func testWhenSetConfigContainsExpandedStateThenModelSettingIsSetToExpanded() async throws {
        model.isViewExpanded = false
        let config = NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: .expanded)
        try await messageHelper.handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(model.isViewExpanded, true)
    }

    func testWhenSetConfigContainsCollapsedStateThenModelSettingIsSetToCollapsed() async throws {
        model.isViewExpanded = true
        let config = NewTabPageUserScript.WidgetConfig(animation: .noAnimation, expansion: .collapsed)
        try await messageHelper.handleMessageExpectingNilResponse(named: .setConfig, parameters: config)
        XCTAssertEqual(model.isViewExpanded, false)
    }

    // MARK: - getData

    func testThatGetDataReturnsCardsFromTheModel() async throws {
        model.cards = [
            .addAppToDockMac,
            .duckplayer,
            .bringStuff
        ]
        let data: NewTabPageDataModel.NextStepsData = try await messageHelper.handleMessage(named: .getData)
        XCTAssertEqual(data, .init(content: [
            .init(id: .addAppToDockMac),
            .init(id: .duckplayer),
            .init(id: .bringStuff)
        ]))
    }

    func testWhenCardsAreEmptyThenGetDataReturnsNilContent() async throws {
        model.cards = []
        let data: NewTabPageDataModel.NextStepsData = try await messageHelper.handleMessage(named: .getData)
        XCTAssertEqual(data, .init(content: nil))
    }

    // MARK: - willDisplayCardsPublisher

    func testThatWillDisplayCardsPublisherIsSentAfterGetDataAndGetConfigAreCalled() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]

        try await performAndWaitForWillDisplayCards {
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer]])
    }

    func testThatWillDisplayCardsPublisherIsNotSentBeforeGetConfigIsCalled() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]

        try await performAndWaitForWillDisplayCards(count: 0, timeout: 0.1) {
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [])

        try await performAndWaitForWillDisplayCards {
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer]])
    }

    func testThatWillDisplayCardsPublisherIsNotSentBeforeGetDataIsCalled() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]

        try await performAndWaitForWillDisplayCards(count: 0, timeout: 0.1) {
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [])

        try await performAndWaitForWillDisplayCards {
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer]])
    }

    func testThatWillDisplayCardsPublisherIsSentAfterUpdatingCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        model.isViewExpanded = true
        try await triggerInitialCardsEventAndResetMockState()

        try await performAndWaitForWillDisplayCards {
            model.cards = [.addAppToDockMac, .duckplayer, .bringStuff]
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [[.addAppToDockMac, .duckplayer, .bringStuff]])
    }

    func testWhenCardsAreUpdatedThenWillDisplayCardsEventOnlyContainsCurrentlyVisibleCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        model.isViewExpanded = false
        try await triggerInitialCardsEventAndResetMockState()

        try await performAndWaitForWillDisplayCards(count: 3) {
            model.cards = [.addAppToDockMac, .duckplayer, .bringStuff]
            model.cards = [.duckplayer, .addAppToDockMac, .bringStuff]
            model.cards = [.addAppToDockMac, .emailProtection, .duckplayer]
        }

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

        try await performAndWaitForWillDisplayCards(count: 2) {
            model.cards = [.addAppToDockMac, .duckplayer, .bringStuff]
            model.cards = []
            model.cards = [.addAppToDockMac, .emailProtection, .duckplayer]
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [
            [.addAppToDockMac, .duckplayer],
            [.addAppToDockMac, .emailProtection]
        ])
    }

    func testThatWillDisplayCardsPublisherIsSentAfterExpandingViewToRevealMoreCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer, .emailProtection, .bringStuff, .defaultApp]
        model.isViewExpanded = false
        try await triggerInitialCardsEventAndResetMockState()

        try await performAndWaitForWillDisplayCards {
            model.isViewExpanded = true
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [[.emailProtection, .bringStuff, .defaultApp]])
    }

    func testThatWillDisplayCardsPublisherIsSentAfterExpandingViewAndNotRevealingMoreCards() async throws {
        model.cards = [.addAppToDockMac, .duckplayer]
        model.isViewExpanded = false
        try await triggerInitialCardsEventAndResetMockState()

        try await performAndWaitForWillDisplayCards(count: 0, timeout: 0.5) {
            model.isViewExpanded = true
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [])
    }

    func testThatWillDisplayCardsPublisherIsNotSentAfterCollapsingView() async throws {
        model.cards = [.addAppToDockMac, .duckplayer, .emailProtection]
        model.isViewExpanded = true
        try await triggerInitialCardsEventAndResetMockState()

        try await performAndWaitForWillDisplayCards(count: 0, timeout: 0.5) {
            model.isViewExpanded = false
        }

        XCTAssertEqual(model.willDisplayCardsCalls, [])
    }

    // MARK: - Helper functions

    func triggerInitialCardsEventAndResetMockState() async throws {
        try await performAndWaitForWillDisplayCards {
            try await messageHelper.handleMessageIgnoringResponse(named: .getConfig)
            try await messageHelper.handleMessageIgnoringResponse(named: .getData)
        }
        model.willDisplayCardsCalls = []
    }

    func performAndWaitForWillDisplayCards(count expectedCount: Int = 1, timeout: TimeInterval = 0.1, _ block: () async throws -> Void) async throws {
        let originalImpl = model.willDisplayCardsImpl

        let expectation = self.expectation(description: "willDisplayCards_waitForWillDisplayCards")
        if expectedCount == 0 {
            expectation.isInverted = true
        } else {
            expectation.expectedFulfillmentCount = expectedCount
        }
        model.willDisplayCardsImpl = { _ in expectation.fulfill() }

        try await block()

        await fulfillment(of: [expectation], timeout: timeout)

        model.willDisplayCardsImpl = originalImpl
    }
}
