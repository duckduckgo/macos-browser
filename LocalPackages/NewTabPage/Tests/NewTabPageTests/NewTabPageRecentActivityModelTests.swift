//
//  NewTabPageRecentActivityModelTests.swift
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

import Combine
import PersistenceTestingUtils
import PrivacyStats
import TrackerRadarKit
import XCTest
@testable import NewTabPage

final class NewTabPageRecentActivityModelTests: XCTestCase {
    private var model: NewTabPageRecentActivityModel!

    private var activityProvider: CapturingNewTabPageRecentActivityProvider!
    private var actionsHandler: CapturingRecentActivityActionsHandler!
    private var settingsPersistor: UserDefaultsNewTabPageRecentActivitySettingsPersistor!

    private var userScript: NewTabPageUserScript!
    private var messageHelper: MessageHelper<NewTabPageRecentActivityClient.MessageName>!

    override func setUp() async throws {
        try await super.setUp()

        activityProvider = CapturingNewTabPageRecentActivityProvider()
        actionsHandler = CapturingRecentActivityActionsHandler()
        settingsPersistor = UserDefaultsNewTabPageRecentActivitySettingsPersistor(MockKeyValueStore(), getLegacySetting: nil)

        model = NewTabPageRecentActivityModel(
            activityProvider: activityProvider,
            actionsHandler: actionsHandler,
            settingsPersistor: settingsPersistor
        )
    }

    func testThatAddFavoriteForwardsTheCallToActionsHandler() async throws {
        let validURLString = "https://example.com"
        await model.addFavorite(validURLString)
        XCTAssertEqual(actionsHandler.addFavoriteCalls, [try XCTUnwrap(URL(string: validURLString))])
    }

    func testWhenURLIsInvalidThenAddFavoriteDoesNotForwardTheCallToActionsHandler() async throws {
        let invalidURLString = "aaaa"
        await model.addFavorite(invalidURLString)
        XCTAssertEqual(actionsHandler.addFavoriteCalls, [])
    }

    func testThatRemoveFavoriteForwardsTheCallToActionsHandler() async throws {
        let validURLString = "https://example.com"
        await model.removeFavorite(validURLString)
        XCTAssertEqual(actionsHandler.removeFavoriteCalls, [try XCTUnwrap(URL(string: validURLString))])
    }

    func testWhenURLIsInvalidThenRemoveFavoriteDoesNotForwardTheCallToActionsHandler() async throws {
        let invalidURLString = "aaaa"
        await model.removeFavorite(invalidURLString)
        XCTAssertEqual(actionsHandler.removeFavoriteCalls, [])
    }

    func testThatConfirmBurnForwardsTheCallToActionsHandler() async throws {
        let validURLString = "https://example.com"
        _ = await model.confirmBurn(validURLString)
        XCTAssertEqual(actionsHandler.confirmBurnCalls, [try XCTUnwrap(URL(string: validURLString))])
    }

    func testWhenURLIsInvalidThenConfirmBurnDoesNotForwardTheCallToActionsHandler() async throws {
        let invalidURLString = "aaaa"
        _ = await model.confirmBurn(invalidURLString)
        XCTAssertEqual(actionsHandler.confirmBurnCalls, [])
    }

    func testThatOpenForwardsTheCallToActionsHandler() async throws {
        let validURLString = "https://example.com"
        await model.open(validURLString, target: .current)
        XCTAssertEqual(actionsHandler.openCalls, [.init(url: try XCTUnwrap(URL(string: validURLString)), target: .current)])
    }

    func testWhenURLIsInvalidThenOpenDoesNotForwardTheCallToActionsHandler() async throws {
        let invalidURLString = "aaaa"
        await model.open(invalidURLString, target: .current)
        XCTAssertEqual(actionsHandler.openCalls, [])
    }

    func testWhenIsViewExpandedIsUpdatedThenPersistorIsUpdated() {
        model.isViewExpanded = true
        XCTAssertTrue(settingsPersistor.isViewExpanded)

        model.isViewExpanded = false
        XCTAssertFalse(settingsPersistor.isViewExpanded)

        model.isViewExpanded = true
        XCTAssertTrue(settingsPersistor.isViewExpanded)
    }
}
