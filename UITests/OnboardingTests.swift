//
//  OnboardingTests.swift
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

import Foundation
import XCTest

@MainActor
class OnboardingTests: XCTestCase {

    var app = XCUIApplication()

    var windows: XCUIElementQuery {
        app.windows
    }

    let helloUrl = URL.testsServer.appendingTestParameters(data: "hello, world!".data(using: .utf8)!).absoluteString.dropping(prefix: "http://")

    override func setUp() async throws {
        continueAfterFailure = false

        app.uiTestsEnvironment[.suppressMoveToApplications] = .true
        app.uiTestsEnvironment[.disableOnboardingAnimations] = .true

        #if DEBUG
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Onboarding tests not supported on DEBUG builds"])
        #elseif !REVIEW
        fatalError("REVIEW scheme should be used. This will clear the onboarding state, comment-out this line if you‘re sure you want to proceed")
        #endif
    }

    private func clickAddressBar() {
        let addressBarCenter = windows.staticTexts["AddressBar-passive"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        addressBarCenter.tap()
    }

    // MARK: - Tests

    func testWhenNewUser_onboardingLaunched() async throws {
        app.uiTestsEnvironment[.onboardingFinished] = .false
        app.uiTestsEnvironment[.shouldRestorePreviousSession] = .true
        app.uiTestsEnvironment[.resetSavedState] = .true

        // run the app with without saved state and with onboardingFinished flag not set
        app.launch()

        // onboarding should start
        XCTAssertTrue(windows.images["OnboardingDax"].exists)

        // go through onboarding
        windows.buttons["Get Started"].click()
        windows.buttons["Maybe Later"].click()
        windows.buttons["Maybe Later"].click()

        // now navigation should work
        clickAddressBar()
        windows.textFields["AddressBar"].typeText(helloUrl)
        windows.textFields["AddressBar"].typeText("\r")

        for _ in 0..<30 {
            if XCUIApplication().windows.webViews.staticTexts["hello, world!"].exists { break }
            try await Task.sleep(interval: 0.1)
        }
        XCTAssertTrue(XCUIApplication().windows.webViews.staticTexts["hello, world!"].exists)

        // quit
        app.typeKey("q", modifierFlags: .command)

        // restart the app with onboardingFinished flag not set – onboarding shouldn‘t start
        app = XCUIApplication()
        app.launch()

        // onboarding shouldn‘t start
        XCTAssertFalse(windows.images["OnboardingDax"].exists)
        // session should restore
        XCTAssertTrue(XCUIApplication().windows.webViews.staticTexts["hello, world!"].exists)
    }

    func testWhenExistingUserWithonboardingFinishedNotSet_onboardingNotLaunched() async throws {
        app.uiTestsEnvironment[.onboardingFinished] = .true
        app.uiTestsEnvironment[.shouldRestorePreviousSession] = .true
        app.uiTestsEnvironment[.resetSavedState] = .true

        // run app with State Restoration On
        app.launch()

        clickAddressBar()

        // open a page
        windows.textFields["AddressBar"].typeText(helloUrl)
        windows.textFields["AddressBar"].typeText("\r")
        try await Task.sleep(interval: 0.3)

        // quit
        app.typeKey("q", modifierFlags: .command)

        // restart the app with onboardingFinished flag not set – onboarding shouldn‘t start
        app = XCUIApplication()
        app.uiTestsEnvironment[.onboardingFinished] = .false
        app.launch()

        // onboarding shouldn‘t start
        XCTAssertFalse(windows.images["OnboardingDax"].exists)
        // session should restore
        for _ in 0..<30 {
            if XCUIApplication().windows.webViews.staticTexts["hello, world!"].exists { break }
            try await Task.sleep(interval: 0.1)
        }
        XCTAssertTrue(XCUIApplication().windows.webViews.staticTexts["hello, world!"].exists)
    }

}
