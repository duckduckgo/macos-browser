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
    let expectation = XCTestExpectation()

    @MainActor override func setUp() {
        super.setUp()
        UserDefaultsWrapper<Any>.clearAll()
        mockTrackerMessageProvider = MockTrackerMessageProvider(expectation: expectation)
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

    func test_OnSiteVisit_WhenStateIsShowTryASearch_returnsTryASearch() {
        let states: [ContextualOnboardingState] = [.showTryASearch]
        tab.url = URL.duckDuckGo

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .tryASearch)
        }
    }

    func test_OnSiteVisit_WhenStateIsTrackerRelatedOrFireUsedShowSearchDone_andPrivacyInfoNil_returnsNil() {
        let states: [ContextualOnboardingState] = [.showBlockedTrackers, .showMajorOrNoTracker, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker, .fireUsedShowSearchDone]
        tab.url = URL.duckDuckGo

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertNil(dialogType)
        }
    }

    func test_OnSiteVisit_WhenStateIsTrackerRelatedOrFireUsedShowSearchDone_() {
        //TODO 
    }

    func test_OnSiteVisit_WhenStateIsShowFireButton_returnsTryFireButton() {
        let states: [ContextualOnboardingState] = [.showFireButton]
        tab.url = URL.duckDuckGo

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .tryFireButton)
        }
    }

    func test_OnSiteVisit_WhenStateIsShowHighFive_returnsHighFive() {
        let states: [ContextualOnboardingState] = [.showHighFive]
        tab.url = URL.duckDuckGo

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .highFive)
        }
    }

    func test_OnSiteVisit_WhenOtherStates_returnsNil() {
        let states: [ContextualOnboardingState] = [
            .notStarted,
            .showTryASite,
            .fireUsedTryASearchShown,
            .onboardingCompleted]
        tab.url = URL.duckDuckGo

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, nil)
        }
    }

    func test_OnGotItPressed_WhenStateIsShowSearchDoneOrfireUsedShowSearchDone_ThenStateTransitionsToShowTryASite() {
           let states: [ContextualOnboardingState] = [
               .showSearchDone,
               .fireUsedShowSearchDone]

        for state in states {
            stateMachine.state = state
            stateMachine.gotItPressed()
            XCTAssertEqual(stateMachine.state, .showTryASite)
        }
    }

    func test_OnGotItPressed_WhenStateIsTrackerRelated_ThenStateTransitionsToShowFireButton() {
           let states: [ContextualOnboardingState] = [
               .showBlockedTrackers,
               .showMajorOrNoTracker,
               .searchDoneShowBlockedTrackers,
               .searchDoneShowMajorOrNoTracker]

        for state in states {
            stateMachine.state = state
            stateMachine.gotItPressed()
            XCTAssertEqual(stateMachine.state, .showFireButton)
        }
    }

    func test_OnGotItPressed_WhenStateIsShowFireButton_ThenStateTransitionsToShowHighFive() {
           let states: [ContextualOnboardingState] = [
               .showFireButton]

        for state in states {
            stateMachine.state = state
            stateMachine.gotItPressed()
            XCTAssertEqual(stateMachine.state, .showHighFive)
        }
    }

    func test_OnGotItPressed_WhenStateIsShowHighFive_ThenStateTransitionsToOnboardingCompleted() {
           let states: [ContextualOnboardingState] = [
               .showHighFive]

        for state in states {
            stateMachine.state = state
            stateMachine.gotItPressed()
            XCTAssertEqual(stateMachine.state, .onboardingCompleted)
        }
    }

    func test_OnGotItPressed_WhenOtherState_ThenNoStateTransition() {
           let states: [ContextualOnboardingState] = [
               .notStarted,
               .showTryASearch,
               .showTryASite,
               .fireUsedTryASearchShown,
               .onboardingCompleted]

        for state in states {
            stateMachine.state = state
            stateMachine.gotItPressed()
            XCTAssertEqual(stateMachine.state, state)
        }
    }

    func test_OnFireButtonUsed_WhenStateIsShowTryASearch_ThenStateTransitionsToFireUsedTryASearchShown() {
           let states: [ContextualOnboardingState] = [
               .showTryASearch]

        for state in states {
            stateMachine.state = state
            stateMachine.fireButtonUsed()
            XCTAssertEqual(stateMachine.state, .fireUsedTryASearchShown)
        }
    }

    func test_OnFireButtonUsed_WhenStateIsFireUsedShowSearchDone_ThenStateTransitionsToShowHighFive() {
           let states: [ContextualOnboardingState] = [
               .fireUsedShowSearchDone]

        for state in states {
            stateMachine.state = state
            stateMachine.fireButtonUsed()
            XCTAssertEqual(stateMachine.state, .showHighFive)
        }
    }

    func test_OnFireButtonUsed_WhenStateIsTrackerRelatedOrOrShowTryASiteOrShowSearchDone_ThenStateTransitionsToShowFireButton() {
        let states: [ContextualOnboardingState] = [
            .showMajorOrNoTracker,
            .showBlockedTrackers,
            .showTryASite,
            .searchDoneShowBlockedTrackers,
            .searchDoneShowMajorOrNoTracker,
            .showSearchDone]

        for state in states {
            stateMachine.state = state
            stateMachine.fireButtonUsed()
            XCTAssertEqual(stateMachine.state, .showFireButton)
        }
    }

    func test_OnFireButtonUsed_WhenStateIsShowHighFive_ThenNoStateTransition() {
           let states: [ContextualOnboardingState] = [
               .notStarted,
               .fireUsedTryASearchShown,
               .showFireButton,
               .onboardingCompleted]

        for state in states {
            stateMachine.state = state
            stateMachine.fireButtonUsed()
            XCTAssertEqual(stateMachine.state, state)
        }
    }

//    @MainActor
//    func test_OnSiteVisit_WhenStateIsTrackerRelatedOrFireUsedShowSearchDone_andPrivacyInfoNotNil_returnsNil() async {
//        let states: [ContextualOnboardingState] = [.showBlockedTrackers, .showMajorOrNoTracker, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker, .fireUsedShowSearchDone]
//        let expectedURL = URL(string: "bbc.com")!
////        tab.navigateTo(url: expectedURL)
//        _=await tab.setUrl(expectedURL, source: .link)?.result
//
//    }

}

class MockTrackerMessageProvider: TrackerMessageProviding {
    let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func trackerMessage(privacyInfo: PrivacyInfo?) -> NSAttributedString? {
        expectation.fulfill()
        return NSAttributedString(string: "Trackers Detected")
    }

    func trackersType(privacyInfo: PrivacyInfo?) -> OnboardingTrackersType? {
        return .blockedTrackers(entityNames: ["entuty1", "entity2"])
    }
}
