//
//  NewTabPageModeDeciderTests.swift
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

import PersistenceTestingUtils
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NewTabPageModeDeciderTests: XCTestCase {
    var keyValueStore: MockKeyValueStore!
    var decider: NewTabPageModeDecider!

    override func setUp() async throws {
        try await super.setUp()

        keyValueStore = MockKeyValueStore()
    }

    func testThatWhenOnboardingIsNotFinishedThenIsNewUserReturnsTrue() {
        keyValueStore.set(false, forKey: UserDefaultsWrapper<Bool>.Key.onboardingFinished.rawValue)

        decider = NewTabPageModeDecider(keyValueStore: keyValueStore)
        XCTAssertEqual(decider.isNewUser, true)
    }

    func testThatWhenOnboardingFinishedFlagIsNotPresentThenIsNewUserReturnsTrue() {
        keyValueStore.removeObject(forKey: UserDefaultsWrapper<Bool>.Key.onboardingFinished.rawValue)

        decider = NewTabPageModeDecider(keyValueStore: keyValueStore)
        XCTAssertEqual(decider.isNewUser, true)
    }

    func testThatWhenOnboardingIsFinishedThenIsNewUserReturnsFalse() {
        keyValueStore.set(true, forKey: UserDefaultsWrapper<Bool>.Key.onboardingFinished.rawValue)

        decider = NewTabPageModeDecider(keyValueStore: keyValueStore)
        XCTAssertEqual(decider.isNewUser, false)
    }

    func testWhenIsNewUserAndOverrideIsNotSetThenModeIsPrivacyStats() {
        keyValueStore.set(false, forKey: UserDefaultsWrapper<Bool>.Key.onboardingFinished.rawValue)
        decider = NewTabPageModeDecider(keyValueStore: keyValueStore)
        decider.modeOverride = nil

        XCTAssertEqual(decider.effectiveMode, .privacyStats)
    }

    func testWhenIsNotNewUserAndOverrideIsNotSetThenModeIsRecentActivity() {
        keyValueStore.set(true, forKey: UserDefaultsWrapper<Bool>.Key.onboardingFinished.rawValue)
        decider = NewTabPageModeDecider(keyValueStore: keyValueStore)
        decider.modeOverride = nil

        XCTAssertEqual(decider.effectiveMode, .recentActivity)
    }

    func testWhenOverrideIsSetToPrivacyStatsThenModeIsPrivacyStats() {
        decider = NewTabPageModeDecider(keyValueStore: keyValueStore)
        decider.modeOverride = .privacyStats

        XCTAssertEqual(decider.effectiveMode, .privacyStats)
    }

    func testWhenOverrideIsSetToRecentActivityThenModeIsRecentActivity() {
        decider = NewTabPageModeDecider(keyValueStore: keyValueStore)
        decider.modeOverride = .recentActivity

        XCTAssertEqual(decider.effectiveMode, .recentActivity)
    }
}
