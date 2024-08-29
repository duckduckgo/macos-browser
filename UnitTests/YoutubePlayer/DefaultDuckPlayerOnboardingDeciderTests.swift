//
//  DefaultDuckPlayerOnboardingDeciderTests.swift
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

final class DefaultDuckPlayerOnboardingDeciderTests: XCTestCase {

    var decider: DefaultDuckPlayerOnboardingDecider!
    var defaults: UserDefaults!
    static let defaultsName = "TestDefaults"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: DefaultDuckPlayerOnboardingDeciderTests.defaultsName)!
        decider = DefaultDuckPlayerOnboardingDecider(defaults: defaults)
    }

    override func tearDown() {
        super.tearDown()
        defaults.removePersistentDomain(forName: DefaultDuckPlayerOnboardingDeciderTests.defaultsName)
    }

    func testCanDisplayOnboarding_InitiallyReturnsTrue() {
        XCTAssertTrue(decider.canDisplayOnboarding)
    }

    func testCanDisplayOnboarding_ReturnsFalseAfterSettingOnboardingAsDone() {
        decider.setOnboardingAsDone()
        XCTAssertFalse(decider.canDisplayOnboarding)
    }

    func testShouldOpenFirstVideoOnDuckPlayer_InitiallyReturnsFalse() {
        XCTAssertFalse(decider.shouldOpenFirstVideoOnDuckPlayer)
    }

    func testShouldOpenFirstVideoOnDuckPlayer_ReturnsTrueAfterSettingOpenFirstVideo() {
        decider.setOpenFirstVideoOnDuckPlayer()
        XCTAssertTrue(decider.shouldOpenFirstVideoOnDuckPlayer)
    }

    func testShouldOpenFirstVideoOnDuckPlayer_ReturnsFalseAfterSettingFirstVideoAsDone() {
        decider.setOpenFirstVideoOnDuckPlayer()
        XCTAssertTrue(decider.shouldOpenFirstVideoOnDuckPlayer)

        decider.setFirstVideoInDuckPlayerAsDone()
        XCTAssertFalse(decider.shouldOpenFirstVideoOnDuckPlayer)
    }

    func testSetOnboardingAsDone_canDisplayOnboardingReturnsFalse() {
        XCTAssertTrue(decider.canDisplayOnboarding)
        decider.setOnboardingAsDone()
        XCTAssertFalse(decider.canDisplayOnboarding)
    }

    func testCanDisplayOnboarding_WhenAlwaysAskAndNotInteracted() {
        let preferences = DuckPlayerPreferences(
            persistor: DuckPlayerPreferencesPersistorMock(
                duckPlayerMode: .alwaysAsk,
                youtubeOverlayInteracted: false,
                youtubeOverlayAnyButtonPressed: false
            )
        )

        let onboardingDecider = DefaultDuckPlayerOnboardingDecider(defaults: defaults, preferences: preferences)
        XCTAssertTrue(onboardingDecider.canDisplayOnboarding)
    }

    func testCanDisplayOnboarding_WhenAlwaysAskAndInteracted() {
        let preferences = DuckPlayerPreferences(
            persistor: DuckPlayerPreferencesPersistorMock(
                duckPlayerMode: .alwaysAsk,
                youtubeOverlayInteracted: false,
                youtubeOverlayAnyButtonPressed: true
            )
        )

        let onboardingDecider = DefaultDuckPlayerOnboardingDecider(defaults: defaults, preferences: preferences)
        XCTAssertFalse(onboardingDecider.canDisplayOnboarding)
    }

    func testCanDisplayOnboarding_WhenEnabled() {
        let preferences = DuckPlayerPreferences(
            persistor: DuckPlayerPreferencesPersistorMock(
                duckPlayerMode: .enabled,
                youtubeOverlayInteracted: false,
                youtubeOverlayAnyButtonPressed: false
            )
        )

        let onboardingDecider = DefaultDuckPlayerOnboardingDecider(defaults: defaults, preferences: preferences)
        XCTAssertFalse(onboardingDecider.canDisplayOnboarding)
    }

    func testCanDisplayOnboarding_WhenDisabled() {
        let preferences = DuckPlayerPreferences(
            persistor: DuckPlayerPreferencesPersistorMock(
                duckPlayerMode: .disabled,
                youtubeOverlayInteracted: false,
                youtubeOverlayAnyButtonPressed: false
            )
        )

        let onboardingDecider = DefaultDuckPlayerOnboardingDecider(defaults: defaults, preferences: preferences)
        XCTAssertFalse(onboardingDecider.canDisplayOnboarding)
    }

    func testCanDisplayOnboarding_WhenOnboardingWasDisplayed() {
        let preferences = DuckPlayerPreferences(
            persistor: DuckPlayerPreferencesPersistorMock(
                duckPlayerMode: .alwaysAsk,
                youtubeOverlayInteracted: false,
                youtubeOverlayAnyButtonPressed: false
            )
        )

        let onboardingDecider = DefaultDuckPlayerOnboardingDecider(defaults: defaults, preferences: preferences)
        onboardingDecider.setOnboardingAsDone()
        XCTAssertFalse(onboardingDecider.canDisplayOnboarding)
    }

    func testReset_ResetsAllFlagsToFalse() {
        decider.setOnboardingAsDone()
        decider.setOpenFirstVideoOnDuckPlayer()
        decider.setFirstVideoInDuckPlayerAsDone()
        decider.reset()

        XCTAssertTrue(decider.canDisplayOnboarding)
        XCTAssertFalse(decider.shouldOpenFirstVideoOnDuckPlayer)
    }
}
