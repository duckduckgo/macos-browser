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

//final class OnboardingUITests: XCTestCase {
//
//    override func setUpWithError() throws {
//        try resetApplicationData()
//    }
//
//    override func tearDownWithError() throws {
//        try resetApplicationData()
//        try disableOnboading()
//    }
//
//    func testOnboardingToBrowsing() throws {
//        continueAfterFailure = false
//        let app = XCUIApplication()
//        app.launchEnvironment["UITEST_MODE"] = "1"
//        app.launch()
//        app.typeKey("w", modifierFlags: [.command, .option, .shift])
//        app.typeKey("n", modifierFlags: .command)
//        let welcomeWindow = app.windows["Welcome"]
//
//        XCTAssertFalse(welcomeWindow.buttons["NavigationBarViewController.optionsButton"].isEnabled)
//
//        // Get Started
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Tired of being tracked online? We can help!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].buttons["Get Started"].click()
//
//        // Default Privacy
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Unlike other browsers, DuckDuckGo comes with privacy by default"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Private Search"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Advanced Tracking Protection"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Automatic Cookie Pop-Up Blocking"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let gotItButton = welcomeWindow.webViews["Welcome"].buttons["Got It"]
//        gotItButton.click()
//
//        // Fewer adds and popups
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Private also means fewer ads and pop-ups"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["While browsing the web"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].buttons["See With Tracker Blocking"].click()
//        gotItButton.click()
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["While watching YouTube"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].buttons["See With Duck Player"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Got It"].click()
//        welcomeWindow.webViews["Welcome"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Next"].click()
//
//        // Make Privacy your to go
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Make privacy your go-to"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].buttons["Skip"].click()
//        welcomeWindow.webViews["Welcome"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Import"].click()
//        welcomeWindow.sheets.buttons["Cancel"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Skip"].click()
//        welcomeWindow.webViews["Welcome"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Next"].click()
//
//        // Customize your experience
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Customize your experience"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Make DuckDuckGo work just the way you want."].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].buttons["Show Bookmarks Bar"].click()
//        XCTAssertTrue(welcomeWindow.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].buttons["Enable Session Restore"].click()
//        welcomeWindow.webViews["Welcome"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Show Home Button"].click()
//        XCTAssertTrue(welcomeWindow.children(matching: .button).element(boundBy: 3).waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Next"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Start Browsing"].click()
//
//        // AfterOnboarding
//        let duckduckgoPrivacySimplifiedWindow = app.windows["DuckDuckGo — Privacy, simplified."]
//        XCTAssertTrue(duckduckgoPrivacySimplifiedWindow.webViews["DuckDuckGo — Privacy, simplified."].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(duckduckgoPrivacySimplifiedWindow.buttons["NavigationBarViewController.optionsButton"].isEnabled)
//    }
//
//    func resetApplicationData() throws {
//        let commands = [
//            "/usr/bin/defaults delete com.duckduckgo.macos.browser.review",
//            "/bin/rm -rf ~/Library/Containers/com.duckduckgo.macos.browser.review/Data",
//            "/usr/bin/defaults write com.duckduckgo.macos.browser.review moveToApplicationsFolderAlertSuppress 1"
//        ]
//
//        for command in commands {
//            try runCommand(command)
//        }
//    }
//
//    func disableOnboading() throws {
//        try runCommand("/usr/bin/defaults write com.duckduckgo.macos.browser.review onboarding.finished -bool true")
//    }
//
//    func runCommand(_ command: String) throws {
//        let process = Process()
//        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
//        process.arguments = ["-c", command]
//
//        try process.run()
//        process.waitUntilExit()
//
//        if process.terminationStatus != 0 {
//            throw NSError(domain: "ProcessErrorDomain", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command)"])
//        }
//    }
//
//}
