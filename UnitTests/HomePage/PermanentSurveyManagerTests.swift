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
import Common
@testable import DuckDuckGo_Privacy_Browser

final class PermanentSurveyManagerTests: XCTestCase {

    var privacyConfigManager: MockPrivacyConfigurationManager!
    var privacyConfig: MockPrivacyConfiguration!
    var statisticsStore: MockStatisticsStore!
    let userDefaults = UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier!).\(NSApplication.runType)")!

    override func setUp() {
        privacyConfigManager = MockPrivacyConfigurationManager()
        privacyConfig = MockPrivacyConfiguration()
        statisticsStore = MockStatisticsStore()
    }

    override func tearDown() {
        privacyConfigManager = nil
        privacyConfig = nil
        statisticsStore = nil
    }

    func test_surveyManagerReturnsExpectedStrings() {
        let expectedTitle = "Help Us Improve"
        let expectedBody = "Take our short survey and help us build the best browser."
        let expectedAction = "Share Your Thoughts"

        XCTAssertEqual(PermanentSurveyManager.title, expectedTitle)
        XCTAssertEqual(PermanentSurveyManager.body, expectedBody)
        XCTAssertEqual(PermanentSurveyManager.actionTitle, expectedAction)
    }

    @MainActor func test_surveyManagerReturnsExpectedURL() {
        let urlString = "https://someUrl.com"
        let atb = "someAtb"
        let someVariant = "someVariant"
        statisticsStore.atb = atb
        statisticsStore.variant = someVariant
        let expectedURL = URL(string: "\(urlString)?atb=\(atb)&v=\(someVariant)&ddg=\(AppVersion.shared.versionNumber)&macos=\(AppVersion.shared.majorAndMinorOSVersion)")
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, firstDay: 0, lastDay: 0, sharePercentage: 0)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, statisticsStore: statisticsStore)

        let actualURL = manager.url

        XCTAssertEqual(actualURL, expectedURL)
    }

    @MainActor func test_wheninvalidURLInConfig_ThenSurveyManagerReturnsExpectedURL() {
        let urlString = "ht tps://someUrl.com"
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, firstDay: 0, lastDay: 0, sharePercentage: 0)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, statisticsStore: statisticsStore)

        let actualURL = manager.url

        XCTAssertNil(actualURL)
    }

    @MainActor func test_surveyIsEnabled_andFirstInstallInTargetRange_andIsRightLocale_andInSureveyShare_ThenPermanentSureveyIsAvalable() {
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        userDefaults.set(sixDaysAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageUserInSurveyShare.rawValue)
        let urlString = "https://someUrl.com"
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 59
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, firstDay: 5, lastDay: 8, sharePercentage: 60)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable = manager.isSurveyAvailable

        XCTAssertTrue(isSurveyAvailable)
        XCTAssertEqual(randomGenerator.capturedRange, 0..<100)

        let manager2 = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable2 = manager.isSurveyAvailable

        XCTAssertTrue(isSurveyAvailable2)
    }

    @MainActor func test_surveyIsDisabled_andFirstInstallInTargetRange_andIsRightLocale_andInSureveyShare_ThenPermanentSureveyIsNotAvalable() {
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        userDefaults.set(sixDaysAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageUserInSurveyShare.rawValue)
        let urlString = "https://someUrl.com"
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 59
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "disabled", url: urlString, firstDay: 5, lastDay: 8, sharePercentage: 60)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable = manager.isSurveyAvailable

        XCTAssertFalse(isSurveyAvailable)
    }

    @MainActor func test_surveyIsEnabled_andFirstInstallBeforeTargetRange_andIsRightLocale_andInSureveyShare_ThenPermanentSureveyIsNotAvalable() {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        userDefaults.set(oneDayAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageUserInSurveyShare.rawValue)
        let urlString = "https://someUrl.com"
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 59
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, firstDay: 5, lastDay: 8, sharePercentage: 60)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable = manager.isSurveyAvailable

        XCTAssertFalse(isSurveyAvailable)
    }

    @MainActor func test_surveyIsEnabled_andInstallAfterTargetRange_andIsRightLocale_andInSureveyShare_ThenPermanentSureveyIsNotAvalable() {
        let nineDaysAgo = Calendar.current.date(byAdding: .day, value: -9, to: Date())!
        userDefaults.set(nineDaysAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageUserInSurveyShare.rawValue)
        let urlString = "https://someUrl.com"
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 59
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, firstDay: 5, lastDay: 8, sharePercentage: 60)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable = manager.isSurveyAvailable

        XCTAssertFalse(isSurveyAvailable)
    }

    @MainActor func test_surveyIsEnabled_andInstallInTargetRange_andIsRightLocale_andBucketedOutsideInSureveyShare_ThenPermanentSureveyIsNotAvalable() {
        let nineDaysAgo = Calendar.current.date(byAdding: .day, value: -9, to: Date())!
        userDefaults.set(nineDaysAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(nil, forKey: UserDefaultsWrapper<Bool?>.Key.homePageUserInSurveyShare.rawValue)
        let urlString = "https://someUrl.com"
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 61
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, firstDay: 5, lastDay: 8, sharePercentage: 60)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable = manager.isSurveyAvailable

        XCTAssertFalse(isSurveyAvailable)
    }

    @MainActor func test_surveyIsEnabled_andInstallInTargetRange_andIsRightLocale_andRegisteredOutsideInSureveyShare_ThenPermanentSureveyIsNotAvalable() {
        let nineDaysAgo = Calendar.current.date(byAdding: .day, value: -9, to: Date())!
        userDefaults.set(nineDaysAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool?>.Key.homePageUserInSurveyShare.rawValue)
        let urlString = "https://someUrl.com"
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 9
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, firstDay: 5, lastDay: 8, sharePercentage: 60)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable = manager.isSurveyAvailable

        XCTAssertFalse(isSurveyAvailable)
    }

    @MainActor func test_surveyIsEnabled_andInstallInTargetRange_andIsNotInRightLocale_andInSureveyShare_ThenPermanentSureveyIsNotAvalable() {
        let nineDaysAgo = Calendar.current.date(byAdding: .day, value: -9, to: Date())!
        userDefaults.set(nineDaysAgo, forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue)
        userDefaults.set(false, forKey: UserDefaultsWrapper<Bool?>.Key.homePageUserInSurveyShare.rawValue)
        let urlString = "https://someUrl.com"
        let randomGenerator = MockRandomNumberGenerator()
        randomGenerator.numberToReturn = 9
        let newTabContinueSetUpSettings = createNewTabContinueSetUpSettings(state: "enabled", url: urlString, localization: "disabled", firstDay: 5, lastDay: 8, sharePercentage: 60)
        privacyConfig.featureSettings = newTabContinueSetUpSettings
        privacyConfigManager.privacyConfig = privacyConfig
        let manager = PermanentSurveyManager(privacyConfigurationManager: privacyConfigManager, randomNumberGenerator: randomGenerator, statisticsStore: statisticsStore)

        let isSurveyAvailable = manager.isSurveyAvailable

        XCTAssertFalse(isSurveyAvailable)
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

class MockRandomNumberGenerator: RandomNumberGenerating {
    var numberToReturn = 0
    var capturedRange: Range<Int>?
    func random(in range: Range<Int>) -> Int {
        capturedRange = range
        return numberToReturn
    }
}
