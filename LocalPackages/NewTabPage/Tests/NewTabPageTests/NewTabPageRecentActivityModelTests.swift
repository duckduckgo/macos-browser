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
import PrivacyStats
import TestUtils
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

    func testWhenIsViewExpandedIsUpdatedThenPersistorIsUpdated() {
        model.isViewExpanded = true
        XCTAssertTrue(settingsPersistor.isViewExpanded)

        model.isViewExpanded = false
        XCTAssertFalse(settingsPersistor.isViewExpanded)

        model.isViewExpanded = true
        XCTAssertTrue(settingsPersistor.isViewExpanded)
    }
}
