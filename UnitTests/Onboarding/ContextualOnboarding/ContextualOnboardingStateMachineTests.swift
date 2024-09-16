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

//    enum ContextualOnboardingState: String {
//        case notStarted
//        case showTryASearch
//        case showSearchDone
//        case showBlockedTrackers
//        case showMajorOrNoTracker
//        case showTryASite
//        case searchDoneShowBlockedTrackers
//        case searchDoneShowMajorOrNoTracker
//        case fireUsedTryASearchShown
//        case fireUsedShowSearchDone
//        case showFireButton
//        case showHighFive
//        case onboardingCompleted
//    }

//    private func dialogPerSearch() -> ContextualDialogType? {
//        switch state {
//        case .showSearchDone, .fireUsedShowSearchDone:
//            return .searchDone(shouldFollowUp: true)
//        case .showBlockedTrackers, .showMajorOrNoTracker:
//            return .searchDone(shouldFollowUp: false)
//        case .showTryASite:
//            return .tryASite
//        case .showFireButton:
//            return .tryFireButton
//        case .showHighFive:
//            return .highFive
//        default:
//            return nil
//        }
//    }

    // Test initial state
    func testDefaultStateIsOnboardingCompleted() {
        XCTAssertEqual(stateMachine.state, .onboardingCompleted)
    }

    func test_OnSearch_WhenStateIsShowSearchDone_returnsSearchDone() {
        let states: [ContextualOnboardingState] = [.showSearchDone, .fireUsedShowSearchDone]

        for state in states {
            stateMachine.state = state
            let dialogType = stateMachine.dialogTypeForTab(tab)
            XCTAssertEqual(dialogType, .searchDone(shouldFollowUp: true))
        }
    }
//
//    // Test site visit triggering try a search dialog
//    func testDialogTypeForTab_whenVisitingSiteInNotStartedState_triggersTryASearch() {
//        let mockSiteTab = MockTab(url: URL(string: "https://example.com")!)
//        stateMachine.state = .notStarted
//        let dialogType = stateMachine.dialogTypeForTab(mockSiteTab)
//        XCTAssertEqual(dialogType, .tryASearch)
//    }
//
//    // Test search performed changes state correctly
//    func testSearchPerformed_updatesStateCorrectly() {
//        stateMachine.state = .showTryASearch
//        stateMachine.searchPerformed()
//        XCTAssertEqual(stateMachine.state, .showSearchDone)
//    }
//
//    // Test blocked trackers case
//    func testSiteVisited_withBlockedTrackers_showsBlockedTrackersDialog() {
//        stateMachine.state = .showTryASearch
//        let dialogType = stateMachine.dialogTypeForTab(mockTab)
//        XCTAssertEqual(dialogType, .trackers(message: NSAttributedString(string: "Trackers Detected"), shouldFollowUp: true))
//    }
//
//    // Test gotItPressed transitions
//    func testGotItPressed_searchDoneMovesToTryASite() {
//        stateMachine.state = .showSearchDone
//        stateMachine.gotItPressed()
//        XCTAssertEqual(stateMachine.state, .showTryASite)
//    }
//
//    func testGotItPressed_blockedTrackersMovesToShowFireButton() {
//        stateMachine.state = .showBlockedTrackers
//        stateMachine.gotItPressed()
//        XCTAssertEqual(stateMachine.state, .showFireButton)
//    }
//
//    // Test fire button used transitions
//    func testFireButtonUsed_tryASearchMovesToFireUsedTryASearchShown() {
//        stateMachine.state = .showTryASearch
//        stateMachine.fireButtonUsed()
//        XCTAssertEqual(stateMachine.state, .fireUsedTryASearchShown)
//    }
//
//    func testFireButtonUsed_showSearchDoneMovesToShowHighFive() {
//        stateMachine.state = .fireUsedShowSearchDone
//        stateMachine.fireButtonUsed()
//        XCTAssertEqual(stateMachine.state, .showHighFive)
//    }
//
//    // Test high five transitions to onboarding complete
//    func testHighFive_movesToOnboardingCompleted() {
//        stateMachine.state = .showHighFive
//        stateMachine.gotItPressed()
//        XCTAssertEqual(stateMachine.state, .onboardingCompleted)
//    }
//
//    // Test onboarding completed remains in same state
//    func testOnboardingCompleted_doesNotChangeState() {
//        stateMachine.state = .onboardingCompleted
//        stateMachine.gotItPressed()
//        XCTAssertEqual(stateMachine.state, .onboardingCompleted)
//    }
}

class MockTrackerMessageProvider: TrackerMessageProviding {
    func trackerMessage(privacyInfo: PrivacyInfo?) -> NSAttributedString? {
        return NSAttributedString(string: "Trackers Detected")
    }

    func trackersType(privacyInfo: PrivacyInfo?) -> OnboardingTrackersType? {
        return .blockedTrackers(entityNames: ["entuty1", "entity2"])
    }
}

//class MockTab: Tab {
//    var content: TabContent = .url
//    var url: URL?
//    var privacyInfo: PrivacyInfo?
//
//    init(url: URL?) {
//        self.url = url
//    }
//}
//
//extension URL {
//    static let duckDuckGo = URL(string: "https://duckduckgo.com")!
//    var isDuckDuckGoSearch: Bool {
//        return self == .duckDuckGo
//    }
//}
