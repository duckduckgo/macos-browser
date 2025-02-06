//
//  ConfigurationManagerIntegrationTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class ConfigurationManagerIntegrationTests: XCTestCase {

    var configManager: ConfigurationManager!

    override func setUpWithError() throws {
        // use default privacyConfiguration link
        _ = AppConfigurationURLProvider(customPrivacyConfiguration: AppConfigurationURLProvider.Constants.defaultPrivacyConfigurationURL)
        configManager = ConfigurationManager()
    }

    override func tearDownWithError() throws {
        // use default privacyConfiguration link
        _ = AppConfigurationURLProvider(customPrivacyConfiguration: AppConfigurationURLProvider.Constants.defaultPrivacyConfigurationURL)
        configManager = nil
    }

    // Test temporarily disabled due to failure
    func testTdsAreFetchedFromURLBasedOnPrivacyConfigExperiment() async {
        // GIVEN
        await configManager.refreshNow()
        let etag = ContentBlocking.shared.trackerDataManager.fetchedData?.etag
        // use test privacyConfiguration link with tds experiments
        _ = AppConfigurationURLProvider(customPrivacyConfiguration: URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/config/test/macos-config.json")!)

        // WHEN
        await configManager.refreshNow()

        // THEN
        var newEtag = ContentBlocking.shared.trackerDataManager.fetchedData?.etag
        XCTAssertNotEqual(etag, newEtag)
        XCTAssertEqual(newEtag, "\"2ce60c57c3d384f986ccbe2c422aac44\"")

        // RESET
        _ = AppConfigurationURLProvider(customPrivacyConfiguration: AppConfigurationURLProvider.Constants.defaultPrivacyConfigurationURL)
        await configManager.refreshNow()
        let resetEtag  = ContentBlocking.shared.trackerDataManager.fetchedData?.etag
        XCTAssertNotEqual(newEtag, resetEtag)
    }

}
