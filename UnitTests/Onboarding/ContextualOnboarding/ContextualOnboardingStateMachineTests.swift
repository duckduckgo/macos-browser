//
//  ContextualOnboardingStateMachineTests.swift
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
import PrivacyDashboard
@testable import DuckDuckGo_Privacy_Browser

class ContextualOnboardingStateMachineTests: XCTestCase {

    var stateMachine: ContextualOnboardingStateMachine!
    var mockTrackerMessageProvider: MockTrackerMessageProvider!
    var tab: Tab!

    @MainActor override func setUp() {
        super.setUp()
        UserDefaultsWrapper<Any>.clearAll()
        mockTrackerMessageProvider = MockTrackerMessageProvider()
        stateMachine = ContextualOnboardingStateMachine(trackerMessageProvider: mockTrackerMessageProvider)
        tab = Tab(url: URL.duckDuckGo)
    }

    override func tearDown() {
        stateMachine = nil
        mockTrackerMessageProvider = nil
        tab = nil
        super.tearDown()
    }

    func testDefaultStateIsOnboardingCompleted() {
        XCTAssertEqual(stateMachine.state, .onboardingCompleted)
    }

    func test_OnSearch_WhenStateIsShowSearchDoneOrFireUsedShowSearchDone_returnsSearchDoneShouldFollowUp() {
        let states: [ContextualOnboardingState] = [.showSearchDone, .fireUsedShowSearchDone]
        tab.url = URL.makeSearchUrl(from: "query something")

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .searchDone(shouldFollowUp: true))
        }
    }

    func test_OnSearch_WhenStateIsShowTryASite_returnsTryASite() {
        let states: [ContextualOnboardingState] = [.showTryASite]
        tab.url = URL.makeSearchUrl(from: "query something")

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .tryASite)
        }
    }

    func test_OnSearch_WhenStateIsShowBlockedTrackersOrShowMajorOrNoTracker_returnsSearchDoneShouldNotFollowUp() {
        let states: [ContextualOnboardingState] = [.showBlockedTrackers, .showMajorOrNoTracker]
        tab.url = URL.makeSearchUrl(from: "query something")

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .searchDone(shouldFollowUp: false))
        }
    }

    func test_OnSearch_WhenStateIsShowFireButton_returnsTryFireButton() {
        let states: [ContextualOnboardingState] = [.showFireButton]
        tab.url = URL.makeSearchUrl(from: "query something")

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .tryFireButton)
        }
    }

    func test_OnSearch_WhenStateIsShowHighFive_returnsHighFive() {
        let states: [ContextualOnboardingState] = [.showHighFive]
        tab.url = URL.makeSearchUrl(from: "query something")

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .highFive)
        }
    }

    func test_OnSearch_WhenOtherStates_returnsNil() {
        let states: [ContextualOnboardingState] = [
            .notStarted,
            .showTryASearch,
            .searchDoneShowBlockedTrackers,
            .searchDoneShowMajorOrNoTracker,
            .fireUsedTryASearchShown,
            .onboardingCompleted]
        tab.url = URL.makeSearchUrl(from: "query something")

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, nil)
        }
    }

}

class MockTrackerMessageProvider: TrackerMessageProviding {
    func trackerMessage(privacyInfo: PrivacyInfo?) -> NSAttributedString? {
        return NSAttributedString(string: "Trackers Detected")
    }

    func trackersType(privacyInfo: PrivacyInfo?) -> OnboardingTrackersType? {
        return .blockedTrackers(entityNames: ["entuty1", "entity2"])
    }
}
