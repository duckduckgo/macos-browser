//
//  PermanentSurveyManagerTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class PermanentSurveyManagerTests: XCTestCase {

    func testPermanentSurveyManagerReturnsExpectedSurvey() throws {
        let url = "https://someUrl.com"
        let firstDay = Int.random(in: 0...365)
        let lastDay = Int.random(in: 0...365)
        let sharePercentage = Int.random(in: 0...365)
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: url, firstDay: firstDay, lastDay: lastDay, sharePercentage: sharePercentage)

        let privacyConfigManager = MockPrivacyConfigurationManager()
        let privacyConfig = MockPrivacyConfiguration()
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager)

        let actualSurevy = manager.survey

        let expectedSurvey = Survey(url: URL(string: url)!, isLocalized: true, firstDay: firstDay, lastDay: lastDay, sharePercentage: sharePercentage)
        XCTAssertEqual(expectedSurvey, actualSurevy)
    }

    func testPermanentSurveyManagerReturnsExpectedSurveyLocalizazionDesavled() throws {
        let url = "https://someUrl.com"
        let firstDay = Int.random(in: 0...365)
        let lastDay = Int.random(in: 0...365)
        let sharePercentage = Int.random(in: 0...365)
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: url, localization: "disabled", firstDay: firstDay, lastDay: lastDay, sharePercentage: sharePercentage)

        let privacyConfigManager = MockPrivacyConfigurationManager()
        let privacyConfig = MockPrivacyConfiguration()
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager)

        let actualSurevy = manager.survey

        let expectedSurvey = Survey(url: URL(string: url)!, isLocalized: false, firstDay: firstDay, lastDay: lastDay, sharePercentage: sharePercentage)
        XCTAssertEqual(expectedSurvey, actualSurevy)
    }

    func testWhenSurveyDisabledPermanentSurveyManagerReturnsNil() throws {
        let url = "https://someUrl.com"
        let firstDay = Int.random(in: 0...365)
        let lastDay = Int.random(in: 0...365)
        let sharePercentage = Int.random(in: 0...365)
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "disabled", url: url, firstDay: firstDay, lastDay: lastDay, sharePercentage: sharePercentage)

        let privacyConfigManager = MockPrivacyConfigurationManager()
        let privacyConfig = MockPrivacyConfiguration()
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager)

        let actualSurevy = manager.survey

        XCTAssertNil(actualSurevy)
    }

    func testWhenSurveyURLWrongPermanentSurveyManagerReturnsNil() throws {
        let url = "ht tp://example.com"
        let firstDay = Int.random(in: 0...365)
        let lastDay = Int.random(in: 0...365)
        let sharePercentage = Int.random(in: 0...365)
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: url, firstDay: firstDay, lastDay: lastDay, sharePercentage: sharePercentage)

        let privacyConfigManager = MockPrivacyConfigurationManager()
        let privacyConfig = MockPrivacyConfiguration()
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager)

        let actualSurevy = manager.survey

        XCTAssertNil(actualSurevy)
    }

    private func createNewTabContinueSetUpSettings(state: String, url: String, localization: String = "enabled", firstDay: Int, lastDay: Int, sharePercentage: Int) -> [String: Any] {
        let newTabContinueSetUpSettings: [String: Any] = [
            "permanentSurvey": [
                "firstDay": firstDay,
                "lastDay": lastDay,
                "localization": localization,
                "sharePercentage": sharePercentage,
                "state": state,
                "url": url
            ]
        ]
        return newTabContinueSetUpSettings
    }

}
