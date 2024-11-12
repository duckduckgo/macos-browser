//
//  FireWindowTests.swift
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

class FireWindowTests: XCTestCase {
    private var app: XCUIApplication!
    private var settingsGeneralButton: XCUIElement!
    private var reopenAllWindowsFromLastSessionPreference: XCUIElement!

    override class func setUp() {
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"

        settingsGeneralButton = app.buttons["PreferencesSidebar.generalButton"]
        reopenAllWindowsFromLastSessionPreference = app.radioButtons["PreferencesGeneralView.stateRestorePicker.reopenAllWindowsFromLastSession"]

        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
    }

    func testFireWindowDoesNotStoreHistory() {
        openFireWindow()
        openSite(pageTitle: "Some site")
        openNormalWindow()
        assertSiteIsNotShowingInNormalWindowHistory()
    }

    func testFireWindowStateIsNotSavedAfterRestart() {
        openNormalWindow()
        app.typeKey(",", modifierFlags: [.command]) // Open settings
        settingsGeneralButton.click(forDuration: 0.5, thenDragTo: settingsGeneralButton)
        reopenAllWindowsFromLastSessionPreference.clickAfterExistenceTestSucceeds()

        openThreeSitesOnNormalWindow()
        openFireWindow()
        openThreeSitesOnFireWindow()

        app.terminate()
        app.launch()

        assertSitesOpenedInNormalWindowAreRestored()
        assertSitesOpenedOnFireWindowAreNotRestored()
    }

    func testFireWindowDoNotShowPinnedTabs() {
        openNormalWindow()
        openSite(pageTitle: "Page #1")
        app.menuItems["Pin Tab"].tap()

        app.openNewTab()
        openSite(pageTitle: "Page #2")
        app.menuItems["Pin Tab"].tap()

        openFireWindow()
        assertFireWindowDoesNotHavePinnedTabs()
    }

    func testFireWindowTabsCannotBeDragged() {
        openFireWindow()
        openSite(pageTitle: "Page #1")

        app.openNewTab()
        openSite(pageTitle: "Page #2")

        dragFirstTabOutsideOfFireWindow()

        /// Assert that Page #1 is still on the fire window after the drag
        app.typeKey("]", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Sample text for Page #2"].exists)
        app.typeKey("[", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Sample text for Page #1"].exists)
    }

    func testFireWindowsSignInDoesNotShowCredentialsPopup() {
        openFireWindow()
        app.openNewTab()
        openSignUpSite()
        fillCredentials()
        finishSignUp()
        assertSavePasswordPopupIsNotShown()
    }

    func testCrendentialsAreAutoFilledInFireWindows() {
        openNormalWindow()
        app.openNewTab()
        openLoginSite()
        signIn()
        saveCredentials()

        /// Here we start the same flow but in the fire window, but we use the autofill credentials saved in the step before.
        openFireWindow()
        app.openNewTab()
        openLoginSite()
        signInUsingAutoFill()
    }

    // MARK: - Utilities

    private func signInUsingAutoFill() {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 13 {
            let webViewFire = app.webViews.firstMatch
            let webViewCoordinate = webViewFire.coordinate(withNormalizedOffset: CGVector(dx: 5, dy: 5))
            webViewCoordinate.tap()
            app.typeKey("\t", modifierFlags: [])
            sleep(1)
            let autoFillPopup = webViewFire.buttons["test@duck.com privacy-test-pages.site"]
            let coordinate = autoFillPopup.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()

            // TODO: How can I check the value?
            XCTAssertTrue(webViewFire.staticTexts["test@duck.com"].exists)
        } else {
            let webViewFire = app.webViews.firstMatch
            webViewFire.tap()
            let emailTextFieldFire = webViewFire.textFields["Email"].firstMatch
            emailTextFieldFire.click()
            let autoFillPopup = webViewFire.buttons["test@duck.com privacy-test-pages.site"]
            let coordinate = autoFillPopup.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            coordinate.tap()

            XCTAssertEqual(emailTextFieldFire.value as? String, "test@duck.com")
        }
    }

    private func saveCredentials() {
        let saveButton = app.buttons["Save"]
        saveButton.tap()
    }

    private func signIn() {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 13 {
            let webView = app.webViews.firstMatch
            let webViewCoordinate = webView.coordinate(withNormalizedOffset: CGVector(dx: 5, dy: 5))
            webViewCoordinate.tap()
            app.typeKey("\t", modifierFlags: [])
            app.typeText("test@duck.com")
            app.typeKey("\t", modifierFlags: [])
            app.typeText("pa$$word")
        } else {
            let webView = app.webViews.firstMatch
            webView.tap()
            let emailTextField = webView.textFields["Email"].firstMatch
            emailTextField.click()
            emailTextField.typeText("test@duck.com")
            app.typeKey("\t", modifierFlags: [])
            app.typeText("pa$$word")
        }

        let signInButton = app.webViews.firstMatch.buttons["Sign in"].firstMatch
        signInButton.click()
    }

    private func openLoginSite() {
        let addressBarTextField = app.windows.firstMatch.textFields["AddressBarViewController.addressBarTextField"].firstMatch
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(URL(string: "https://privacy-test-pages.site/autofill/autoprompt/1-standard-login-form.html")!)
        XCTAssertTrue(
            app.windows.firstMatch.webViews["Autofill autoprompt for signin forms"].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
    }

    private func assertSavePasswordPopupIsNotShown() {
        let credentialsPopup = app.popovers["Save password in DuckDuckGo?"]
        XCTAssertFalse(credentialsPopup.exists)
    }

    private func finishSignUp() {
        let signUpButton = app.webViews.firstMatch.buttons["Sign up"].firstMatch
        signUpButton.click()
    }

    private func fillCredentials() {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 13 {
            /// On macOS 13 we tap in the webview coordinate and we use tabs to make it work given that it doesn't find web view elements
            let webView = app.webViews.firstMatch
            let webViewCoordinate = webView.coordinate(withNormalizedOffset: CGVector(dx: 5, dy: 5))
            webViewCoordinate.tap()
            app.typeKey("\t", modifierFlags: [])
            app.typeText("test@duck.com")
            app.typeKey("\t", modifierFlags: [])
            app.typeText("pa$$word")
            app.typeKey("\t", modifierFlags: [])
            app.typeText("pa$$word")
        } else {
            let webView = app.webViews.firstMatch
            webView.tap()
            let emailTextField = webView.textFields["Email"].firstMatch
            emailTextField.click()
            emailTextField.typeText("test@duck.com")

            let password = webView.secureTextFields["Password"].firstMatch
            password.click()
            password.typeText("pa$$word")
            app.typeKey("\t", modifierFlags: [])
            app.typeText("pa$$word")
        }
    }

    private func openSignUpSite() {
        let addressBarTextField = app.windows.firstMatch.textFields["AddressBarViewController.addressBarTextField"].firstMatch  
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(URL(string: "https://privacy-test-pages.site/autofill/signup.html")!)
        XCTAssertTrue(
            app.windows.firstMatch.webViews["Password generation during signup"].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
    }

    private func dragFirstTabOutsideOfFireWindow() {
        let toolbar = app.toolbars.firstMatch
        let toolbarCoordinate = toolbar.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let startPoint = toolbarCoordinate.withOffset(CGVector(dx: 120, dy: 15))
        let endPoint = toolbarCoordinate.withOffset(CGVector(dx: -100, dy: -100))
        startPoint.press(forDuration: 0.5, thenDragTo: endPoint)
    }

    private func assertFireWindowDoesNotHavePinnedTabs() {
        let existsPredicate = NSPredicate(format: "exists == true")
        let staticTextExistsExpectation = expectation(for: existsPredicate, evaluatedWith: app.windows.firstMatch.staticTexts.element(boundBy: 0), handler: nil)

        // Wait up to 10 seconds for the static texts to be available
        let result = XCTWaiter().wait(for: [staticTextExistsExpectation], timeout: 10)
        XCTAssertEqual(result, .completed, "No static texts were found in the app")

        // After confirming static texts are available, iterate through them
        for staticText in app.staticTexts.allElementsBoundByIndex {
            if staticText.exists {
                XCTAssertFalse(staticText.label.contains("Page #1"), "Unwanted string found in static text: \(staticText.label)")
                XCTAssertFalse(staticText.label.contains("Page #2"), "Unwanted string found in static text: \(staticText.label)")
            }
        }
    }

    private func assertSitesOpenedInNormalWindowAreRestored() {
        XCTAssertTrue(app.staticTexts["Sample text for Page #3"].waitForExistence(timeout: UITests.Timeouts.elementExistence), "Page #3 should exist.")
        app.typeKey("[", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Sample text for Page #2"].waitForExistence(timeout: UITests.Timeouts.elementExistence), "Page #2 should exist.")
        app.typeKey("[", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Sample text for Page #1"].waitForExistence(timeout: UITests.Timeouts.elementExistence), "Page #1 should exist.")
    }

    private func assertSitesOpenedOnFireWindowAreNotRestored() {
        let existsPredicate = NSPredicate(format: "exists == true")
        let staticTextExistsExpectation = expectation(for: existsPredicate, evaluatedWith: app.staticTexts.element(boundBy: 0), handler: nil)

        // Wait up to 10 seconds for the static texts to be available
        let result = XCTWaiter().wait(for: [staticTextExistsExpectation], timeout: 10)
        XCTAssertEqual(result, .completed, "No static texts were found in the app")

        // After confirming static texts are available, iterate through them
        for staticText in app.staticTexts.allElementsBoundByIndex {
            if staticText.exists {
                XCTAssertFalse(staticText.label.contains("Page #4"), "Unwanted string found in static text: \(staticText.label)")
                XCTAssertFalse(staticText.label.contains("Page #5"), "Unwanted string found in static text: \(staticText.label)")
                XCTAssertFalse(staticText.label.contains("Page #6"), "Unwanted string found in static text: \(staticText.label)")
            }
        }
    }

    private func openThreeSitesOnNormalWindow() {
        app.openNewTab()
        openSite(pageTitle: "Page #1")
        app.openNewTab()
        openSite(pageTitle: "Page #2")
        app.openNewTab()
        openSite(pageTitle: "Page #3")
    }

    private func openThreeSitesOnFireWindow() {
        openSite(pageTitle: "Page #4")
        app.openNewTab()
        openSite(pageTitle: "Page #5")
        app.openNewTab()
        openSite(pageTitle: "Page #6")
    }

    private func cleanAllHistory() {
        app.typeKey(.delete, modifierFlags: [.command, .shift])
        let clearButton = app.buttons["Clear"].firstMatch
        XCTAssertTrue(clearButton.exists, "Clear button should exist")
        clearButton.tap()
    }

    private func assertSiteIsNotShowingInNormalWindowHistory() {
        let siteMenuItemInHistory = app.menuItems["Some site"]
        XCTAssertFalse(siteMenuItemInHistory.exists, "Menu item should not exist because it was not stored in history.")
    }

    private func openFireWindow() {
        app.typeKey("n", modifierFlags: [.command, .shift])
    }

    private func openNormalWindow() {
        app.typeKey("n", modifierFlags: .command)
    }

    private func openSite(pageTitle: String) {
        let url = UITests.simpleServedPage(titled: pageTitle)
        let addressBarTextField = app.windows.firstMatch.textFields["AddressBarViewController.addressBarTextField"].firstMatch
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(url)
        XCTAssertTrue(
            app.windows.firstMatch.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
    }
}
