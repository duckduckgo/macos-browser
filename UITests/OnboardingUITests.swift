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

final class OnboardingUITests: XCTestCase {

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
           welcomeWindow.webViews["Welcome"].staticTexts["Ready for a faster browser that keeps you protected?"].click()

           let getStartedButton = welcomeWindow.webViews["Welcome"].buttons["Let’s Do It!"]
           XCTAssertTrue(getStartedButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           getStartedButton.click()

           XCTAssertTrue(welcomeWindow.webViews["Welcome"].groups["Protections activated!"].staticTexts["Protections activated!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
           welcomeWindow.webViews["Welcome"].groups["Protections activated!"].staticTexts["Protections activated!"].click()

           let skipButton = welcomeWindow.webViews["Welcome"].buttons["Skip"]
           XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           skipButton.click()

           XCTAssertTrue(welcomeWindow.webViews["Welcome"].groups["Let’s get you set up!"].staticTexts["Let’s get you set up!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
           welcomeWindow.webViews["Welcome"].groups["Let’s get you set up!"].staticTexts["Let’s get you set up!"].click()

           // Import Now
           XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           skipButton.click()

           let importNowButton = welcomeWindow.webViews["Welcome"].buttons["Import Now"]
           XCTAssertTrue(importNowButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           importNowButton.click()

           let cancelButton = welcomeWindow.sheets.buttons["Cancel"]
           XCTAssertTrue(cancelButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           cancelButton.click()

           let nextButton = welcomeWindow.webViews["Welcome"].buttons["Next"]
           XCTAssertTrue(nextButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           nextButton.click()

           // Duck Player
           XCTAssertTrue(welcomeWindow.webViews["Welcome"].groups["Drowning in ads on YouTube? Not with Duck Player!"].staticTexts["Drowning in ads on YouTube? Not with Duck Player!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
           welcomeWindow.webViews["Welcome"].groups["Drowning in ads on YouTube? Not with Duck Player!"].staticTexts["Drowning in ads on YouTube? Not with Duck Player!"].click()

           XCTAssertTrue(nextButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           nextButton.click()

           // Customize Experience
           XCTAssertTrue(welcomeWindow.webViews["Welcome"].groups["Let’s customize a few things…"].staticTexts["Let’s customize a few things…"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
           welcomeWindow.webViews["Welcome"].groups["Let’s customize a few things…"].staticTexts["Let’s customize a few things…"].click()

           // Session Restore
           XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           skipButton.click()

           let enableSessionRestoreButton = welcomeWindow.webViews["Welcome"].buttons["Enable Session Restore"]
           XCTAssertTrue(enableSessionRestoreButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           enableSessionRestoreButton.click()

           let showHomeButton = welcomeWindow.webViews["Welcome"].buttons["Show Home Button"]
           XCTAssertTrue(showHomeButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           showHomeButton.click()

           XCTAssertTrue(welcomeWindow.children(matching: .button).element(boundBy: 3).waitForExistence(timeout: UITests.Timeouts.elementExistence))

           // Start Browsing
           let startBrowsingButton = welcomeWindow.webViews["Welcome"].buttons["Start Browsing"]
           XCTAssertTrue(startBrowsingButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
           startBrowsingButton.click()

           // After Onboarding
           let duckduckgoPrivacySimplifiedWindow = app.windows["DuckDuckGo — Privacy, simplified."]
           XCTAssertTrue(duckduckgoPrivacySimplifiedWindow.webViews["DuckDuckGo — Privacy, simplified."].waitForExistence(timeout: UITests.Timeouts.elementExistence))
           XCTAssertTrue(duckduckgoPrivacySimplifiedWindow.buttons["NavigationBarViewController.optionsButton"].isEnabled)

//        // Get Started
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Ready for a faster browser that keeps you protected?"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let getStartedButton = welcomeWindow.webViews["Welcome"].buttons["Let’s Do It!"]
//        XCTAssertTrue(getStartedButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        getStartedButton.click()
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Protections activated!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let defaultSkipButton = welcomeWindow.webViews["Welcome"].buttons["Skip"]
//        XCTAssertTrue(defaultSkipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Let’s get you set up!"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//
//        // Default Privacy
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Unlike other browsers, DuckDuckGo comes with privacy by default"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Private Search"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Advanced Tracking Protection"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Automatic Cookie Pop-Up Blocking"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let gotItButton = welcomeWindow.webViews["Welcome"].buttons["Got It"]
//        XCTAssertTrue(gotItButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        gotItButton.click()
//
//        // Fewer ads and popups
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Private also means fewer ads and pop-ups"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["While browsing the web"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let seeWithTrackerBlockingButton = welcomeWindow.webViews["Welcome"].buttons["See With Tracker Blocking"]
//        XCTAssertTrue(seeWithTrackerBlockingButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        seeWithTrackerBlockingButton.click()
//        XCTAssertTrue(gotItButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        gotItButton.click()
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["While watching YouTube"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let seeWithDuckPlayerButton = welcomeWindow.webViews["Welcome"].buttons["See With Duck Player"]
//        XCTAssertTrue(seeWithDuckPlayerButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        seeWithDuckPlayerButton.click()
//        let nextGotItButton = welcomeWindow.webViews["Welcome"].buttons["Got It"]
//        XCTAssertTrue(nextGotItButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        nextGotItButton.click()
//        welcomeWindow.webViews["Welcome"].click()
//        let nextButton = welcomeWindow.webViews["Welcome"].buttons["Next"]
//        XCTAssertTrue(nextButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        nextButton.click()
//
//        // Make Privacy your go-to
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Make privacy your go-to"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let skipButton = welcomeWindow.webViews["Welcome"].buttons["Skip"]
//        XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        skipButton.click()
//        welcomeWindow.webViews["Welcome"].click()
//        let importButton = welcomeWindow.webViews["Welcome"].buttons["Import"]
//        XCTAssertTrue(importButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        importButton.click()
//        let cancelButton = welcomeWindow.sheets.buttons["Cancel"]
//        XCTAssertTrue(cancelButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        cancelButton.click()
//        XCTAssertTrue(skipButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        skipButton.click()
//        welcomeWindow.webViews["Welcome"].click()
//        XCTAssertTrue(nextButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        nextButton.click()
//
//        // Customize your experience
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Customize your experience"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(welcomeWindow.webViews["Welcome"].staticTexts["Make DuckDuckGo work just the way you want."].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let showBookmarksBarButton = welcomeWindow.webViews["Welcome"].buttons["Show Bookmarks Bar"]
//        XCTAssertTrue(showBookmarksBarButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        showBookmarksBarButton.click()
//        XCTAssertTrue(welcomeWindow.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        let enableSessionRestoreButton = welcomeWindow.webViews["Welcome"].buttons["Enable Session Restore"]
//        XCTAssertTrue(enableSessionRestoreButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        enableSessionRestoreButton.click()
//        welcomeWindow.webViews["Welcome"].click()
//        let showHomeButton = welcomeWindow.webViews["Welcome"].buttons["Show Home Button"]
//        XCTAssertTrue(showHomeButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        showHomeButton.click()
//        XCTAssertTrue(welcomeWindow.children(matching: .button).element(boundBy: 3).waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        welcomeWindow.webViews["Welcome"].click()
//        XCTAssertTrue(nextButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        nextButton.click()
//        let startBrowsingButton = welcomeWindow.webViews["Welcome"].buttons["Start Browsing"]
//        XCTAssertTrue(startBrowsingButton.waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        startBrowsingButton.click()
//
//        // AfterOnboarding
//        let duckduckgoPrivacySimplifiedWindow = app.windows["DuckDuckGo — Privacy, simplified."]
//        XCTAssertTrue(duckduckgoPrivacySimplifiedWindow.webViews["DuckDuckGo — Privacy, simplified."].waitForExistence(timeout: UITests.Timeouts.elementExistence))
//        XCTAssertTrue(duckduckgoPrivacySimplifiedWindow.buttons["NavigationBarViewController.optionsButton"].isEnabled)
//

        
//        let app = XCUIApplication()
//        let welcomeWindow = app.windows["Welcome"]
//        welcomeWindow.webViews["Welcome"].staticTexts["Ready for a faster browser that keeps you protected?"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Let’s Do It!"].click()
//        welcomeWindow.webViews["Welcome"].groups["Protections activated!"].staticTexts["Protections activated!"].click()
//
//        let skipButton = welcomeWindow.webViews["Welcome"].buttons["Skip"]
//        skipButton.click()
//        welcomeWindow.webViews["Welcome"].groups["Let’s get you set up!"].staticTexts["Let’s get you set up!"].click()
//        skipButton.click()
//        welcomeWindow.webViews["Welcome"].buttons["Import Now"].click()
//        welcomeWindow.sheets.buttons["Cancel"].click()
//
//        let nextButton = welcomeWindow.webViews["Welcome"].buttons["Next"]
//        nextButton.click()
//        welcomeWindow.webViews["Welcome"].groups["Drowning in ads on YouTube? Not with Duck Player!"].staticTexts["Drowning in ads on YouTube? Not with Duck Player!"].click()
//        nextButton.click()
//        welcomeWindow.webViews["Welcome"].groups["Let’s customize a few things…"].staticTexts["Let’s customize a few things…"].click()
//        skipButton.click()
//        welcomeWindow.webViews["Welcome"].buttons["Enable Session Restore"].click()
//        welcomeWindow.webViews["Welcome"].buttons["Show Home Button"].click()
//        welcomeWindow.children(matching: .button).element(boundBy: 3).click()
//        welcomeWindow.webViews["Welcome"].buttons["Start Browsing"].click()
//
//        let duckduckgoPrivacySimplifiedWindow = app.windows["DuckDuckGo — Privacy, simplified."]
//        duckduckgoPrivacySimplifiedWindow/*@START_MENU_TOKEN@*/.staticTexts["Try a search!"]/*[[".groups.staticTexts[\"Try a search!\"]",".staticTexts[\"Try a search!\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
//        duckduckgoPrivacySimplifiedWindow/*@START_MENU_TOKEN@*/.buttons["cast of avatar"]/*[[".groups.buttons[\"cast of avatar\"]",".buttons[\"cast of avatar\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
//        
//        let castOfAvatarAtDuckduckgoWindow = app.windows["cast of avatar at DuckDuckGo"]
//        castOfAvatarAtDuckduckgoWindow/*@START_MENU_TOKEN@*/.buttons["Got it"]/*[[".groups.buttons[\"Got it\"]",".buttons[\"Got it\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
//        castOfAvatarAtDuckduckgoWindow/*@START_MENU_TOKEN@*/.buttons["yahoo.com"]/*[[".groups.buttons[\"yahoo.com\"]",".buttons[\"yahoo.com\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
//        
//        let yahooMailWeatherSearchPoliticsNewsFinanceWindow = app.windows["Yahoo | Mail, Weather, Search, Politics, News, Finance,…"]
//        yahooMailWeatherSearchPoliticsNewsFinanceWindow/*@START_MENU_TOKEN@*/.buttons["Got it"]/*[[".groups.buttons[\"Got it\"]",".buttons[\"Got it\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
//        yahooMailWeatherSearchPoliticsNewsFinanceWindow/*@START_MENU_TOKEN@*/.buttons["Skip"]/*[[".groups.buttons[\"Skip\"]",".buttons[\"Skip\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
//        yahooMailWeatherSearchPoliticsNewsFinanceWindow/*@START_MENU_TOKEN@*/.buttons["High five!"]/*[[".groups.buttons[\"High five!\"]",".buttons[\"High five!\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        
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
