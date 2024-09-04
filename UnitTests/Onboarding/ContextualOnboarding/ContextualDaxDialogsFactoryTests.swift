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

    override func setUpWithError() throws {
        try super.setUpWithError()
        factory = DefaultContextualDaxDialogViewFactory()
        delegate = CapturingOnboardingNavigationDelegate()
    }

    override func tearDownWithError() throws {
        factory = nil
        delegate = nil
        try super.tearDownWithError()
    }

    func testWhenMakeViewForTryASearchThenOnboardingTrySearchDialogViewCreatedAndOnActionExpectedSearchOccurs() throws {
        // GIVEN
        let dialogType = ContextualDialogType.tryASearch

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: {})

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
        let dialogType = ContextualDialogType.searchDone(shouldFollowUp: true)
        let onDismiss = { onDismissRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss)

        // THEN
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        let subView = find(OnboardingTryVisitingSiteDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.gotItAction()

        // THEN
        XCTAssertFalse(onDismissRun)
    }

    func testWhenMakeViewForSearchDoneWithoutShouldFollowUpThenOnboardingsearchDoneViewCreatedAndOnActionOccurs() throws {
        // GIVEN
        var onDismissRun = false
        let dialogType = ContextualDialogType.searchDone(shouldFollowUp: false)
        let onDismiss = { onDismissRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss)

        // THEN
        let view = try XCTUnwrap(find(OnboardingFirstSearchDoneDialog.self, in: result))
        let subView = find(OnboardingTryVisitingSiteDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.gotItAction()

        // THEN
        XCTAssertTrue(onDismissRun)
    }

    func testWhenMakeViewForTryASiteThenOnboardingTrySiteDialogViewCreatedAndOnActionExpectedSearchOccurs() throws {
        // GIVEN
        let dialogType = ContextualDialogType.tryASite

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: {})

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
        let trackerMessage = NSMutableAttributedString(string: "some trackers")
        let dialogType = ContextualDialogType.trackers(message: trackerMessage, shouldFollowUp: true)
        let onDismiss = { onDismissRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss)

        // THEN
        let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
        let subView = find(OnboardingFireButtonDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.blockedTrackersCTAAction()

        // THEN
        XCTAssertFalse(onDismissRun)
    }

    func testWhenMakeViewForTryASiteWithoutShouldFollowUpThenTryASiteDialogViewCreatedAndOnActionOccurs() throws {
        // GIVEN
        var onDismissRun = false
        let trackerMessage = NSMutableAttributedString(string: "some trackers")
        let dialogType = ContextualDialogType.trackers(message: trackerMessage, shouldFollowUp: false)
        let onDismiss = { onDismissRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss)

        // THEN
        let view = try XCTUnwrap(find(OnboardingTrackersDoneDialog.self, in: result))
        let subView = find(OnboardingFireButtonDialogContent.self, in: result)
        XCTAssertNil(subView)

        // WHEN
        view.blockedTrackersCTAAction()

        // THEN
        XCTAssertTrue(onDismissRun)
    }

    @MainActor func testWhenMakeViewForTryFireButtonThenOnboardingTryFireButtonDialogViewCreatedAndOnActionExpectedActionOccurs() throws {
        // GIVEN
        var onDismissRun = false
        let dialogType = ContextualDialogType.tryFireButton
        let onDismiss = { onDismissRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss)

        // THEN
        let view = try XCTUnwrap(find(OnboardingFireDialog.self, in: result))

        // WHEN
        view.viewModel.skip()
        view.viewModel.tryFireButton()

        // THEN
        XCTAssertTrue(onDismissRun)
        let expectation = self.expectation(description: "Wait for FirePopover to appear")
        self.waitForPopoverToAppear(expectation: expectation)
        wait(for: [expectation], timeout: 3.0)
    }

    func testWhenMakeViewForHighFivThenFilalDialogViewCreatedAndOnActionExpectedSearchOccurs() throws {
        // GIVEN
        var onDismissRun = false
        let dialogType = ContextualDialogType.highFive
        let onDismiss = { onDismissRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss)

        // THEN
        let view = try XCTUnwrap(find(OnboardingFinalDialog.self, in: result))

        // WHEN
        view.highFiveAction()

        // THEN
        XCTAssertTrue(onDismissRun)
    }

    @MainActor private func waitForPopoverToAppear(expectation: XCTestExpectation) {
        if let popover = FireCoordinator.firePopover, popover.isShown {
            // Fulfill the expectation if the popover is shown
            expectation.fulfill()
        } else {
            // If not shown yet, check again after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.waitForPopoverToAppear(expectation: expectation)
            }
        }
    }

}

class CapturingOnboardingNavigationDelegate: OnboardingNavigationDelegate {
    var didCallSearchFor = false
    var didNavigateToCalled = false
    var capturedQuery = ""
    var capturedUrlString = ""

    func searchFor(_ query: String) {
        didCallSearchFor = true
        capturedQuery = query
    }

    func navigateTo(url: URL) {
        didNavigateToCalled = true
        capturedUrlString = url.absoluteString
    }
}

import SwiftUI

/// Recursively searches for a SwiftUI view of type `T` within the given root object.
///
/// - Parameters:
///   - type: The type of view to search for.
///   - root: The root object to start searching from.
/// - Returns: An optional view of type `T`, or `nil` if no such view is found.
func find<T: View>(_ type: T.Type, in root: Any) -> T? {
    let mirror = Mirror(reflecting: root)
    for child in mirror.children {
        if let view = child.value as? T {
            return view
        }
        if let found = find(type, in: child.value) {
            return found
        }
    }
    return nil
}
