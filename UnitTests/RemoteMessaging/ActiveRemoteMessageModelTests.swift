//
//  ActiveRemoteMessageModelTests.swift
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

import Foundation
import XCTest
import RemoteMessaging
@testable import DuckDuckGo_Privacy_Browser

final class ActiveRemoteMessageModelTests: XCTestCase {

    var model: ActiveRemoteMessageModel!
    private var store: MockRemoteMessagingStore!
    var message: RemoteMessageModel!

    override func setUpWithError() throws {
        store = MockRemoteMessagingStore()
        message = RemoteMessageModel(
            id: "1",
            content: .small(titleText: "test", descriptionText: "desc"), matchingRules: [], exclusionRules: [], isMetricsEnabled: false
        )
    }

    func testWhenNoMessageIsScheduledThenRemoteMessageIsNil() throws {
        store.scheduledRemoteMessage = nil
        model = ActiveRemoteMessageModel(
            remoteMessagingStore: self.store,
            remoteMessagingAvailabilityProvider: MockRemoteMessagingAvailabilityProvider(),
            openURLHandler: { _ in }
        )

        XCTAssertNil(model.newTabPageRemoteMessage)
    }

    func testWhenMessageIsScheduledThenItIsLoadedToModel() throws {
        store.scheduledRemoteMessage = message
        model = ActiveRemoteMessageModel(
            remoteMessagingStore: self.store,
            remoteMessagingAvailabilityProvider: MockRemoteMessagingAvailabilityProvider(),
            openURLHandler: { _ in }
        )

        XCTAssertEqual(model.newTabPageRemoteMessage, message)
    }

    func testWhenMessageIsDismissedThenItIsClearedFromModel() async throws {
        store.scheduledRemoteMessage = message
        model = ActiveRemoteMessageModel(
            remoteMessagingStore: self.store,
            remoteMessagingAvailabilityProvider: MockRemoteMessagingAvailabilityProvider(),
            openURLHandler: { _ in }
        )
        await model.dismissRemoteMessage(with: .close)

        XCTAssertNil(model.newTabPageRemoteMessage)
    }

    func testWhenMessageIsMarkedAsShownThenShownFlagIsSavedInStore() async throws {
        store.scheduledRemoteMessage = message
        model = ActiveRemoteMessageModel(
            remoteMessagingStore: self.store,
            remoteMessagingAvailabilityProvider: MockRemoteMessagingAvailabilityProvider(),
            openURLHandler: { _ in }
        )

        XCTAssertFalse(store.hasShownRemoteMessage(withID: message.id))
        await model.markRemoteMessageAsShown()
        XCTAssertTrue(store.hasShownRemoteMessage(withID: message.id))
    }

    func testWhenMessageIsForTabBar_thenCorrectPublisherIsSet() {
        let tabBarRemoteMessage = RemoteMessageModel(
            id: TabBarRemoteMessage.tabBarPermanentSurveyRemoteMessageId,
            content: .bigSingleAction(titleText: "Help Us Improve!",
                                      descriptionText: "Description",
                                      placeholder: .announce,
                                      primaryActionText: "Test",
                                      primaryAction: .survey(value: "www.survey.com")),
            matchingRules: [],
            exclusionRules: [],
            isMetricsEnabled: false
        )
        store.scheduledRemoteMessage = tabBarRemoteMessage
        model = ActiveRemoteMessageModel(
            remoteMessagingStore: self.store,
            remoteMessagingAvailabilityProvider: MockRemoteMessagingAvailabilityProvider(),
            openURLHandler: { _ in }
        )

        XCTAssertNotNil(model.tabBarRemoteMessage)
        XCTAssertNil(model.newTabPageRemoteMessage)
    }

    func testWhenMessageIsForNewTabPage_thenCorrectPublisherIsSet() {
        store.scheduledRemoteMessage = message
        model = ActiveRemoteMessageModel(
            remoteMessagingStore: self.store,
            remoteMessagingAvailabilityProvider: MockRemoteMessagingAvailabilityProvider(),
            openURLHandler: { _ in }
        )

        XCTAssertNil(model.tabBarRemoteMessage)
        XCTAssertNotNil(model.newTabPageRemoteMessage)
    }
}
