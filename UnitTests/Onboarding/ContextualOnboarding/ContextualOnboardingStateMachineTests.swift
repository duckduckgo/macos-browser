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

@available(macOS 12.0, *)
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

    func test_OnSearch_WhenStateIsSearchDoneShowBlockedTrackersOrSearchSoneShowMajorOrNoTracker_returnSearchDoneShouldFollowUpFalse() {
        let states: [ContextualOnboardingState] = [.searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker]
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
            .fireUsedTryASearchShown,
            .onboardingCompleted
        ]
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

    func test_OnSiteVisit_WhenStateIsTrackerRelatedOrFireUsedShowSearchDone_returnsTrackersShouldFollowUp() {
        let states: [ContextualOnboardingState] = [.showBlockedTrackers, .showMajorOrNoTracker, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker, .fireUsedShowSearchDone]
        tab.url = URL.duckDuckGo
        let privacyInfo = PrivacyInfo(url: tab.url!, parentEntity: nil, protectionStatus: ProtectionStatus(unprotectedTemporary: true, enabledFeatures: [], allowlisted: false, denylisted: false), isPhishing: false, shouldCheckServerTrust: true)

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab, privacyInfo: privacyInfo)
            XCTAssertEqual(dialogType, .trackers(message: mockTrackerMessageProvider.message, shouldFollowUp: true))
        }
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
            .searchDoneShowMajorOrNoTracker,
            .searchDoneSeenShowBlockedTrackers,
            .searchDoneSeenShowMajorOrNoTracker]

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
            .tryASiteSeen,
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
            .searchDoneSeenShowBlockedTrackers,
            .searchDoneSeenShowMajorOrNoTracker,
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

    func test_UpdateStateFor_OpensDuckDuckGoSearch_ShowsTryASearch() {
        // Given
        stateMachine.state = .notStarted
        tab.url = URL.duckDuckGo

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showTryASearch)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInShowTryASearch_ShowsSearchDone() {
        // Given
        stateMachine.state = .showTryASearch
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showSearchDone)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInShowSearchDone_ShowsTryASite() {
        // Given
        stateMachine.state = .showSearchDone
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showTryASite)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInShowTryASite_ShowsTryASiteSeen() {
        // Given
        stateMachine.state = .showTryASite
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .tryASiteSeen)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInShowBlockedTrackers_ShowsSearchDoneShowBlockedTrackers() {
        // Given
        stateMachine.state = .showBlockedTrackers
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .searchDoneShowBlockedTrackers)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInShowMajorOrNoTracker_ShowsSearchDoneShowMajorOrNoTracker() {
        // Given
        stateMachine.state = .showMajorOrNoTracker
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .searchDoneShowMajorOrNoTracker)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInSearchDoneShowBlockedTrackers_ShowsSearchDoneSeenShowBlockedTrackers() {
        // Given
        stateMachine.state = .searchDoneShowBlockedTrackers
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .searchDoneSeenShowBlockedTrackers)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInSearchDoneShowMajorOrNoTracker_ShowsSearchDoneSeenShowMajorOrNoTracker() {
        // Given
        stateMachine.state = .searchDoneShowMajorOrNoTracker
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .searchDoneSeenShowMajorOrNoTracker)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInSearchDoneSeenShowBlockedTrackers_ShowsShowFireButton() {
        // Given
        stateMachine.state = .searchDoneSeenShowBlockedTrackers
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showFireButton)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInSearchDoneSeenShowMajorOrNoTracker_ShowsShowFireButton() {
        // Given
        stateMachine.state = .searchDoneSeenShowMajorOrNoTracker
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showFireButton)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInFireUsedShowSearchDone_ShowsShowHighFive() {
        // Given
        stateMachine.state = .fireUsedShowSearchDone
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showHighFive)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInShowHighFive_ShowsOnboardingCompleted() {
        // Given
        stateMachine.state = .showHighFive
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .onboardingCompleted)
    }

    func test_UpdateStateFor_PerformsSearch_WhenInOnboardingCompleted_DoesNotChangeState() {
        // Given
        stateMachine.state = .onboardingCompleted
        tab.url = URL.makeSearchUrl(from: "test search")

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .onboardingCompleted)  // State remains the same
    }

    func test_UpdateStateFor_VisitsSite_WhenInShowTryASearch_ShowsBlockedTrackers() {
        // Given
        stateMachine.state = .showTryASearch
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .blockedTrackers(entityNames: ["Tracker1"])

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showBlockedTrackers)
    }

    func test_UpdateStateFor_VisitsSite_WhenTrackersBlocked_ShowsShowFireButton() {
        // Given
        stateMachine.state = .searchDoneSeenShowBlockedTrackers
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .blockedTrackers(entityNames: ["Tracker1"])

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showFireButton)
    }

    func test_UpdateStateFor_VisitsSite_WhenNoTrackersBlocked_ShowsSearchDoneShowMajorOrNoTracker() {
        // Given
        stateMachine.state = .showSearchDone
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .majorTracker

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .searchDoneSeenShowMajorOrNoTracker)
    }

    func test_UpdateStateFor_VisitsSiteAfterSearch_WithTrackers_MovesToSearchDoneShowBlockedTrackers() {
        // Given
        stateMachine.state = .showSearchDone
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .blockedTrackers(entityNames: ["Tracker1"])

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .searchDoneSeenShowBlockedTrackers)
    }

    func test_UpdateStateFor_VisitsSiteAfterSearch_WithBlockedTrackers_MovesToSearchDoneSeenShowBlockedTrackers() {
        // Given
        stateMachine.state = .searchDoneShowBlockedTrackers
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .blockedTrackers(entityNames: ["Tracker1"])

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showFireButton)
    }

    func test_UpdateStateFor_VisitsSiteAfterSearch_WithNoTrackers_MovesToSearchDoneSeenShowMajorOrNoTracker() {
        // Given
        stateMachine.state = .searchDoneShowMajorOrNoTracker
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .majorTracker

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .searchDoneShowMajorOrNoTracker)
    }

    func test_UpdateStateFor_VisitsSite_TrackersSeen_TransitionsToShowFireButton() {
        // Given
        stateMachine.state = .showBlockedTrackers
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .blockedTrackers(entityNames: ["Tracker1"])

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showFireButton)
    }

    func test_UpdateStateFor_VisitsSite_WithoutTrackers_DoesNotUpdateStateFromShowBlockedTrackers() {
        // Given
        stateMachine.state = .showBlockedTrackers
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .majorTracker

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showFireButton)
    }

    func test_UpdateStateFor_VisitsDuckDuckGoSearch_DoesNotChangeStateFromOnboardingCompleted() {
        // Given
        stateMachine.state = .onboardingCompleted
        tab.url = URL.duckDuckGo

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .onboardingCompleted)
    }

    func test_UpdateStateFor_VisitsSite_NoTrackers_ShowsNoDialog() {
        // Given
        stateMachine.state = .showTryASearch
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .majorTracker

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertNil(stateMachine.dialogTypeForTab(tab))
        XCTAssertEqual(stateMachine.state, .showMajorOrNoTracker)
    }

    func test_UpdateStateFor_VisitsSite_TrackersSeen_ButNotBlocked_DoesNotUpdateState() {
        // Given
        stateMachine.state = .showTryASearch
        tab.url = URL(string: "https://example.com")
        mockTrackerMessageProvider.trackerType = .blockedTrackers(entityNames: ["Tracker1"])
        stateMachine.notBlockedTrackerSeen = true

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showBlockedTrackers)
        XCTAssertTrue(stateMachine.notBlockedTrackerSeen)
    }

    func test_UpdateStateFor_VisitsDuckDuckGoHome_DoesNotUpdateState() {
        // Given
        stateMachine.state = .showTryASearch
        tab.url = URL.duckDuckGo

        // When
        stateMachine.updateStateFor(tab: tab)

        // Then
        XCTAssertEqual(stateMachine.state, .showBlockedTrackers)
    }
}

class MockTrackerMessageProvider: TrackerMessageProviding {

    let expectation: XCTestExpectation
    var message: NSAttributedString
    var trackerType: OnboardingTrackersType?

    init(expectation: XCTestExpectation, message: NSAttributedString = NSAttributedString(string: "Trackers Detected"), trackerType: OnboardingTrackersType? = .blockedTrackers(entityNames: ["entity1", "entity2"])) {
        self.expectation = expectation
        self.message = message
        self.trackerType = trackerType
    }

    func trackerMessage(privacyInfo: PrivacyInfo?) -> NSAttributedString? {
        // Simulate fetching the tracker message
        expectation.fulfill()
        return message
    }

    func trackersType(privacyInfo: PrivacyInfo?) -> OnboardingTrackersType? {
        // Simulate fetching the tracker type
        return trackerType
    }
}
