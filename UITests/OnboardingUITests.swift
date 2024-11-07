//
//  OnboardingUITests.swift
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

final class OnboardingUITests: UITestCase {

    override func tearDownWithError() throws {
        try resetApplicationData()
    }

    func testOnboardingToBrowsing() throws {
        try resetApplicationData()
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE_ONBOARDING"] = "1"
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)
        let welcomeWindow = app.windows["Welcome"]

        let optionsButton = welcomeWindow.buttons["NavigationBarViewController.optionsButton"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        XCTAssertFalse(optionsButton.isEnabled)

        // Get Started
        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Ready for a faster browser that keeps you protected?"].waitForExistence(timeout: UITests.Timeouts.elementExistence))

        let getStartedButton = welcomeWindow.webViews["Welcome"].buttons["Let’s Do It!"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        getStartedButton.click()
        // When it clicks on the button the y it's not alligned
        let centerCoordinate = getStartedButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        centerCoordinate.tap()

        // Protections activated
        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Protections activated!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))

        let skipButton = welcomeWindow.webViews["Welcome"].buttons["Skip"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        skipButton.click()

        // Let’s get you set up
        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Let’s get you set up!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))

        XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        skipButton.click()

        let importNowButton = welcomeWindow.webViews["Welcome"].buttons["Import Now"]
        XCTAssertTrue(importNowButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        importNowButton.click()

        let cancelButton = welcomeWindow.sheets.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        cancelButton.click()

        let nextButtonSetUp = welcomeWindow.webViews["Welcome"].buttons["Next"]
        XCTAssertTrue(nextButtonSetUp.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        nextButtonSetUp.click()

        // Duck Player
        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Drowning in ads on YouTube? Not with Duck Player!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))

        let nextButtonDuckPlayer = welcomeWindow.webViews["Welcome"].buttons["Next"]
        XCTAssertTrue(nextButtonDuckPlayer.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        nextButtonDuckPlayer.click()

        // Customize Experience
        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Let’s customize a few things…"].waitForExistence(timeout: UITests.Timeouts.elementExistence))

        // Session Restore
        XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        skipButton.click()

        let enableSessionRestoreButton = welcomeWindow.webViews["Welcome"].buttons["Enable Session Restore"]
        XCTAssertTrue(enableSessionRestoreButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        enableSessionRestoreButton.click()

        let showHomeButton = welcomeWindow.webViews["Welcome"].buttons["Show Home Button"]
        XCTAssertTrue(showHomeButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        showHomeButton.click()

        // Start Browsing
        let startBrowsingButton = welcomeWindow.webViews["Welcome"].buttons["Start Browsing"]
        XCTAssertTrue(startBrowsingButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        startBrowsingButton.click()

        // AfterOnboarding
        let ddgLogo = app.windows.webViews.groups.containing(.image, identifier: "DuckDuckGo Logo").element
        XCTAssertTrue(ddgLogo.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        let homePageSubTitle = app.windows.webViews.groups.containing(.staticText, identifier: "Your protection, our priority.").element
        XCTAssertTrue(homePageSubTitle.waitForExistence(timeout: UITests.Timeouts.elementExistence))
    }

    func resetApplicationData() throws {
        let commands = [
            "/usr/bin/defaults delete com.duckduckgo.macos.browser.review",
            "/bin/rm -rf ~/Library/Containers/com.duckduckgo.macos.browser.review/Data",
            "/usr/bin/defaults write com.duckduckgo.macos.browser.review moveToApplicationsFolderAlertSuppress 1"
        ]

        for command in commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw NSError(domain: "ProcessErrorDomain", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command)"])
            }
        }
    }
}
