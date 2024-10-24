//
//  ContextualDaxDialogFactoryIntegrationTests.swift
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

final class ContextualDaxDialogFactoryIntegrationTests: XCTestCase {

    private var factory: ContextualDaxDialogsFactory!
    private var delegate: CapturingOnboardingNavigationDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        factory = DefaultContextualDaxDialogViewFactory()
        delegate = CapturingOnboardingNavigationDelegate()
    }

    @MainActor override func tearDownWithError() throws {
        factory = nil
        delegate = nil
        try super.tearDownWithError()
    }

    @MainActor func testWhenMakeViewForTryFireButtonThenOnboardingTryFireButtonDialogViewCreatedAndOnActionExpectedActionOccurs() throws {
        // GIVEN
        var onDismissRun = false
        var onGotItPressedRun = false
        let dialogType = ContextualDialogType.tryFireButton
        let onDismiss = { onDismissRun = true }
        let onGotItPressed = { onGotItPressedRun = true }

        // WHEN
        let result = factory.makeView(for: dialogType, delegate: delegate, onDismiss: onDismiss, onGotItPressed: onGotItPressed, onFireButtonPressed: {})

        // THEN
        let view = try XCTUnwrap(find(OnboardingFireDialog.self, in: result))

        // WHEN
        view.viewModel.skip()
        view.viewModel.tryFireButton()

        // THEN
        XCTAssertFalse(onDismissRun)
        XCTAssertTrue(onGotItPressedRun)
        let expectation = self.expectation(description: "Wait for FirePopover to appear")
        self.waitForPopoverToAppear(expectation: expectation)
        wait(for: [expectation], timeout: 3.0)
        WindowControllersManager.shared.lastKeyMainWindowController?.window?.close()
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
