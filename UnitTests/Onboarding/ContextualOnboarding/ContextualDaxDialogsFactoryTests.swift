//
//  ContextualDaxDialogsFactoryTests.swift
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
import Onboarding
@testable import DuckDuckGo_Privacy_Browser

final class ContextualDaxDialogsFactoryTests: XCTestCase {
    private var factory: ContextualDaxDialogsFactory!
    private var delegate: CapturingOnboardingNavigationDelegate!
    private var reporter: CapturingOnboardingPixelReporter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        reporter = CapturingOnboardingPixelReporter()
        factory = DefaultContextualDaxDialogViewFactory(onboardingPixelReporter: reporter)
        delegate = CapturingOnboardingNavigationDelegate()
    }

    @MainActor override func tearDownWithError() throws {
        factory = nil
        delegate = nil
        reporter = nil
        try super.tearDownWithError()
    }

    func testWhenMakeViewForTryASearchThenOnboardingTrySearchDialogViewCreatedAndOnActionExpectedSearchOccurs() throws {
        // GIVEN
        let dialogType = ContextualDialogType.tryASearch

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: {}, onGotItPressed: {}, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingTrySearchDialog.self, in: result))
        XCTAssertTrue(view.viewModel.delegate === delegate)

        // WHEN
        let query = "some search"
        view.viewModel.listItemPressed(ContextualOnboardingListItem.search(title: query))

        // THEN
        XCTAssertTrue(delegate.didCallSearchFor)
        XCTAssertEqual(delegate.capturedQuery, query)
    }

    func testWhenMakeViewForSearchDoneWithShouldFollowUpThenOnboardingsearchDoneViewCreatedAndOnActionNothingOccurs() throws {
        // GIVEN
        var onDismissRun = false
        var onGotItPressedRun = false
        let dialogType = ContextualDialogType.searchDone(shouldFollowUp: true)
        let onDismiss = { onDismissRun = true }
        let onGotItPressed = { onGotItPressedRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        let subView = find(OnboardingTryVisitingSiteDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.gotItAction()

        // THEN
        XCTAssertFalse(onDismissRun)
        XCTAssertTrue(onGotItPressedRun)
    }

    func testWhenMakeViewForSearchDoneWithoutShouldFollowUpThenOnboardingsearchDoneViewCreatedAndOnActionOccurs() throws {
        // GIVEN
        var onDismissRun = false
        var onGotItPressedRun = false
        let dialogType = ContextualDialogType.searchDone(shouldFollowUp: false)
        let onDismiss = { onDismissRun = true }
        let onGotItPressed = { onGotItPressedRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        let subView = find(OnboardingTryVisitingSiteDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.gotItAction()

        // THEN
        XCTAssertTrue(onDismissRun)
        XCTAssertFalse(onGotItPressedRun)
    }

    func testWhenMakeViewForTryASiteThenOnboardingTrySiteDialogViewCreatedAndOnActionExpectedSearchOccurs() throws {
        // GIVEN
        let dialogType = ContextualDialogType.tryASite

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: {}, onGotItPressed: {}, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingTryVisitingASiteDialog.self, in: result))
        XCTAssertTrue(view.viewModel.delegate === delegate)

        // WHEN
        let urlString = "some.site"
        view.viewModel.listItemPressed(ContextualOnboardingListItem.site(title: urlString))

        // THEN
        XCTAssertTrue(delegate.didNavigateToCalled)
        XCTAssertEqual(delegate.capturedUrlString, urlString)
    }

    func testWhenMakeViewForTryASiteWithShouldFollowUpThenTrySiteDialogViewCreatedAndOnActionNothingOccurs() throws {
        // GIVEN
        var onDismissRun = false
        var onGotItPressedRun = false
        let trackerMessage = NSMutableAttributedString(string: "some trackers")
        let dialogType = ContextualDialogType.trackers(message: trackerMessage, shouldFollowUp: true)
        let onDismiss = { onDismissRun = true }
        let onGotItPressed = { onGotItPressedRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
        let subView = find(OnboardingFireButtonDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.blockedTrackersCTAAction()

        // THEN
        XCTAssertFalse(onDismissRun)
        XCTAssertTrue(onGotItPressedRun)
    }

    func testWhenMakeViewForTryASiteWithoutShouldFollowUpThenTryASiteDialogViewCreatedAndOnActionOccurs() throws {
        // GIVEN
        var onDismissRun = false
        var onGotItPressedRun = false
        let trackerMessage = NSMutableAttributedString(string: "some trackers")
        let dialogType = ContextualDialogType.trackers(message: trackerMessage, shouldFollowUp: false)
        let onDismiss = { onDismissRun = true }
        let onGotItPressed = { onGotItPressedRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
        let subView = find(OnboardingFireButtonDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.blockedTrackersCTAAction()

        // THEN
        XCTAssertTrue(onDismissRun)
        XCTAssertFalse(onGotItPressedRun)
    }

    func testWhenMakeViewForHighFivThenFilalDialogViewCreatedAndOnActionExpectedSearchOccurs() throws {
        // GIVEN
        var onDismissRun = false
        var onGotItPressedRun = false
        let dialogType = ContextualDialogType.highFive
        let onDismiss = { onDismissRun = true }
        let onGotItPressed = { onGotItPressedRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingFinalDialog.self, in: result))

        // WHEN
        view.highFiveAction()

        // THEN
        XCTAssertTrue(onDismissRun)
        XCTAssertTrue(onGotItPressedRun)
    }

    @MainActor
    func testWhenMakeViewForTryFireButtonAndFireButtonIsPressedThenOnFireButtonPressedActionIsCalled() throws {
        // GIVEN
        var onFireButtonRun = false
        let dialogType = ContextualDialogType.tryFireButton
        let onFireButtonPressed = { onFireButtonRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: {}, onGotItPressed: {}, onFireButtonPressed: onFireButtonPressed)

        // THEN
        let view = try XCTUnwrap(find(OnboardingFireDialog.self, in: result))

        // WHEN
        view.viewModel.tryFireButton()

        // THEN
        XCTAssertTrue(onFireButtonRun)
    }

    func testWhenMakeViewForTryFireButtonAndSkipButtonIsPressedThenTrackFireButtonSkippedCalled() throws {
        // GIVEN
        let dialogType = ContextualDialogType.highFive

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: {}, onGotItPressed: {}, onFireButtonPressed: {})

        // THEN
        XCTAssertTrue(reporter.trackLastDialogShownCalled)
    }

}

class CapturingOnboardingPixelReporter: OnboardingPixelReporting {
    var trackFireButtonSkippedCalled = false
    var trackFireButtonTryItCalled = false
    var trackLastDialogShownCalled = false
    var trackSiteVisitedCalled = false

    func trackFireButtonSkipped() {
        trackFireButtonSkippedCalled = true
    }

    func trackLastDialogShown() {
        trackLastDialogShownCalled = true
    }

    func trackSearchSuggetionOptionTapped() {
    }

    func trackSiteSuggetionOptionTapped() {
    }

    func trackFireButtonTryIt() {
        trackFireButtonTryItCalled = true
    }

    func trackAddressBarTypedIn() {
    }

    func trackPrivacyDashboardOpened() {
    }

    func trackSiteVisited() {
        trackSiteVisitedCalled = true
    }
}
