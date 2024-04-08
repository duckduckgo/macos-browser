//
//  CriticalPathsTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import JavaScriptCore

final class CriticalPathsTests: XCTestCase {

    var app: XCUIApplication!
    var debugMenuBarItem: XCUIElement!
    var internaluserstateMenuItem: XCUIElement!

    override func setUp() {
        // Launch App
        app = XCUIApplication(bundleIdentifier: "com.duckduckgo.macos.browser.review")
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
        if app.windows.count == 0 {
            app.menuItems["newWindow:"].click()
        }
        toggleInternalUserState()
        cleanupAndResetData()
    }

    override func tearDown() {
        toggleInternalUserState()
        cleanupAndResetData()
        app.menuItems["closeAllWindows:"].click()
    }

    private func accessSettings() {
        app.menuItems["openPreferences:"].click()
        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(settingsWindow.exists, "Settings window is not visible")
    }

    private func toggleInternalUserState() {
        let menuBarsQuery = app.menuBars
        debugMenuBarItem = menuBarsQuery.menuBarItems["Debug"]
        debugMenuBarItem.click()
        internaluserstateMenuItem = menuBarsQuery.menuItems["internalUserState:"]
        internaluserstateMenuItem.click()
    }

    private func cleanupAndResetData() {
        let menuBarsQuery = app.menuBars
        debugMenuBarItem = menuBarsQuery.menuBarItems["Debug"]

        debugMenuBarItem.click()
        let resetDataMenuItem = menuBarsQuery.menuItems["MainMenu.resetData"]
        resetDataMenuItem.hover()
        let resetBookMarksData = resetDataMenuItem.menuItems["MainMenu.resetBookmarks"]
        resetBookMarksData.click()

        debugMenuBarItem.click()
        resetDataMenuItem.hover()
        let resetAutofillData = resetDataMenuItem.menuItems["MainMenu.resetSecureVaultData"]
        resetAutofillData.click()
    }

    func testCanCreateSyncAccount() throws {
        // Go to Sync Set up
        accessSettings()
        let settingsWindow = app.windows["Settings"]
        settingsWindow.buttons["Sync & Backup"].click()

        // Create Account
        let sheetsQuery = settingsWindow.sheets
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Sync and Back Up This Device"]/*[[".groups",".scrollViews.buttons[\"Sync and Back Up This Device\"]",".buttons[\"Sync and Back Up This Device\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery.buttons["Turn On Sync & Backup"].click()
        _ = sheetsQuery.buttons["Next"].waitForExistence(timeout: 5)
        sheetsQuery.buttons["Next"].click()
        sheetsQuery.buttons["Done"].click()
        let syncEnabledElement = settingsWindow.staticTexts["Sync Enabled"]
        XCTAssertTrue(syncEnabledElement.exists, "Sync Enabled text is not visible")

        // Clean Up
        settingsWindow.swipeUp()
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Turn Off and Delete Server Data…"]/*[[".groups",".scrollViews.buttons[\"Turn Off and Delete Server Data…\"]",".buttons[\"Turn Off and Delete Server Data…\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery.buttons["Delete Data"].click()
        let beginSync = settingsWindow.staticTexts["Begin Syncing"]
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begin Syncing text is not visible")
    }

    func testCanRecoverSyncAccount() throws {
        // Go to Sync Set up
        accessSettings()
        let settingsWindow = app.windows["Settings"]
        settingsWindow.buttons["Sync & Backup"].click()

        // Create Account
        let sheetsQuery = settingsWindow.sheets
        settingsWindow.buttons["Sync and Back Up This Device"].click()
        sheetsQuery.buttons["Turn On Sync & Backup"].click()
        sheetsQuery.buttons["Copy Code"].click()
        sheetsQuery.buttons["Next"].click()
        sheetsQuery.buttons["Done"].click()
        let syncEnabledElement = settingsWindow.staticTexts["Sync Enabled"]
        XCTAssertTrue(syncEnabledElement.exists, "Sync Enabled text is not visible")

        // Log out
        settingsWindow.buttons["Turn Off Sync…"].click()
        sheetsQuery.buttons["Turn Off"].click()

        // Recover Account
        settingsWindow.buttons["Recover Synced Data"].click()
        sheetsQuery.buttons["Get Started"].click()
        sheetsQuery.buttons["Paste"].click()
        sheetsQuery.buttons["Done"].click()
        XCTAssertTrue(syncEnabledElement.exists, "Sync Enabled text is not visible")

        // Clean Up
        settingsWindow.swipeUp()
        settingsWindow.buttons["Turn Off and Delete Server Data…"].click()
        sheetsQuery.buttons["Delete Data"].click()
        let beginSync = settingsWindow.staticTexts["Begin Syncing"]
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begin Sync text is not visible")

    }

    func testCanRemoveData() {

        // Go to Sync Set up
        accessSettings()

        let settingsWindow = app.windows["Settings"]
        settingsWindow.buttons["Sync & Backup"].click()

        // Create Account
        let sheetsQuery = settingsWindow.sheets
        settingsWindow.buttons["Sync and Back Up This Device"].click()
        sheetsQuery.buttons["Turn On Sync & Backup"].click()
        sheetsQuery.buttons["Copy Code"].click()
        sheetsQuery.buttons["Next"].click()
        sheetsQuery.buttons["Done"].click()
        let syncEnabledElement = settingsWindow.staticTexts["Sync Enabled"]
        XCTAssertTrue(syncEnabledElement.exists, "Sync Enabled text is not visible")

        // Delete Data
        settingsWindow.swipeUp()
        settingsWindow.buttons["Turn Off and Delete Server Data…"].click()
        sheetsQuery.buttons["Delete Data"].click()
        let beginSync = settingsWindow.staticTexts["Begin Syncing"]
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begyn Sync text is not visible")

        // Log In and check error
        settingsWindow.buttons["Sync With Another Device"].click()
        let settingsSheetsQuery = settingsWindow.sheets
        settingsSheetsQuery.buttons["Enter Code"].click()
        settingsSheetsQuery.buttons["Paste"].click()
        let alertSheet = sheetsQuery.sheets["alert"]
        alertSheet.staticTexts["Sync & Backup Error"].click()
        XCTAssertTrue(alertSheet.exists, "Sync Error text is not visible")

    }

    func testCanLoginToExistingSyncAccount() {
        guard let code = ProcessInfo.processInfo.environment["CODE"] else {
            XCTFail("CODE not set")
            return
        }

        // Go to Sync Set up
        accessSettings()
        let settingsWindow = app.windows["Settings"]
        settingsWindow.buttons["Sync & Backup"].click()

        // Copy code to clipboard
        copyToClipboard(code: code)

        // Log In
        logIn()

        // Clean Up
        logOut()
    }

    func testCanSyncData() {
        guard let code = ProcessInfo.processInfo.environment["CODE"] else {
            XCTFail("CODE not set")
            return
        }

        // Add Bookmarks and Favorite
        addBookmarksAndFavorites()

        // Add Login
        addLogin()

        // Copy code to clipboard
        copyToClipboard(code: code)

        // Log In
        let bookmarksWindow = app.windows["Bookmarks"]
        bookmarksWindow.splitGroups.children(matching: .popUpButton).element.click()
        bookmarksWindow.menuItems["Settings"].click()
        logIn()

        // Log Out
        logOut()

        // Check Favorites not unified
        checkFavoriteNonUnified()

        // Remove Bookmarks
        bookmarksWindow.staticTexts["www.spreadprivacy.com"].rightClick()
        bookmarksWindow.menus.menuItems["deleteBookmark:"].click()
        bookmarksWindow.staticTexts["www.duckduckgo.com"].rightClick()
        bookmarksWindow.menus.menuItems["deleteBookmark:"].click()

        // Log In
        bookmarksWindow.splitGroups.children(matching: .popUpButton).element.click()
        bookmarksWindow.menuItems["Settings"].click()
        logIn()

        // Toggle Unified Favorite
        let settingsWindow = app.windows["Settings"]
        settingsWindow/*@START_MENU_TOKEN@*/.checkBoxes["Unify Favorites Across Devices"]/*[[".groups",".scrollViews.checkBoxes[\"Unify Favorites Across Devices\"]",".checkBoxes[\"Unify Favorites Across Devices\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()

        // Check Bookmarks
        checkBookmarks()

        // Check Unified favorites
        checkUnifiedFavorites()

        // Check Logins
        // checkLogins()
    }

    private func logIn() {
        let settingsWindow = app.windows["Settings"]
        settingsWindow.buttons["Sync & Backup"].click()
        settingsWindow.buttons["Sync With Another Device"].click()
        let settingsSheetsQuery = settingsWindow.sheets
        settingsSheetsQuery.buttons["Enter Code"].click()
        settingsSheetsQuery.buttons["Paste"].click()
        settingsSheetsQuery.buttons["Next"].click()
        settingsSheetsQuery.buttons["Done"].click()
        let secondDevice = settingsWindow.images["SyncedDeviceMobile"]
        XCTAssertTrue(secondDevice.exists, "Original Device not visible")
    }

    private func logOut() {
        let settingsWindow = app.windows["Settings"]
        let settingsSheetsQuery = settingsWindow.sheets
        settingsWindow.buttons["Turn Off Sync…"].click()
        settingsSheetsQuery.buttons["Turn Off"].click()
        let beginSync = settingsWindow.staticTexts["Begin Syncing"]
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begyn Sync text is not visible")
    }

    private func copyToClipboard(code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(code, forType: .string)
    }

    private func addBookmarksAndFavorites() {
        app.menuItems["showManageBookmarks:"].click()
        let bookmarksWindow = app.windows["Bookmarks"]
        bookmarksWindow.buttons["  New Bookmark"].click()
        let sheetsQuery = app.windows["Bookmarks"].sheets
        sheetsQuery.textFields["Title Text Field"].click()
        sheetsQuery.textFields["Title Text Field"].typeText("www.duckduckgo.com")
        sheetsQuery.textFields["URL Text Field"].click()
        sheetsQuery.textFields["URL Text Field"].typeText("www.duckduckgo.com")
        sheetsQuery.buttons["Add"].click()
        bookmarksWindow.buttons["  New Bookmark"].click()
        sheetsQuery.textFields["Title Text Field"].click()
        sheetsQuery.textFields["Title Text Field"].typeText("www.spreadprivacy.com")
        sheetsQuery.textFields["URL Text Field"].click()
        sheetsQuery.textFields["URL Text Field"].typeText("www.spreadprivacy.com")
        sheetsQuery.buttons["Add"].click()
        bookmarksWindow.staticTexts["www.spreadprivacy.com"].rightClick()
        bookmarksWindow.menuItems["toggleBookmarkAsFavorite:"].click()
    }

    private func addLogin() {
        let bookmarksWindow = app.windows["Bookmarks"]
        bookmarksWindow.buttons["NavigationBarViewController.optionsButton"].click()
        bookmarksWindow.menuItems["Autofill"].click()
        bookmarksWindow.popovers.buttons["add item"].click()
        bookmarksWindow.popovers.menuItems["createNewLogin"].click()
        let usernameTextfieldTextField = bookmarksWindow.popovers.textFields["Username TextField"]
        usernameTextfieldTextField.click()
        usernameTextfieldTextField.typeText("mywebsite")
        let websiteTextfieldTextField = bookmarksWindow.popovers.textFields["Website TextField"]
        websiteTextfieldTextField.click()
        websiteTextfieldTextField.typeText("mywebsite.com")
        bookmarksWindow.popovers.buttons["Save"].click()
    }

    private func checkFavoriteNonUnified() {
        let bookmarksWindow = app.windows["Bookmarks"]
        let settingsWindow = app.windows["Settings"]
        settingsWindow.popUpButtons["Settings"].click()
        settingsWindow.menuItems["Bookmarks"].click()
        bookmarksWindow.outlines.staticTexts["Favorites"].click()
        let gitHub = bookmarksWindow.staticTexts["DuckDuckGo · GitHub"]
        let spreadPrivacy = bookmarksWindow.staticTexts["www.spreadprivacy.com"]
        XCTAssertFalse(gitHub.exists)
        XCTAssertTrue(spreadPrivacy.exists)
        bookmarksWindow.outlines.staticTexts["Bookmarks"].click()
    }

    private func checkBookmarks() {
        let settingsWindow = app.windows["Settings"]
        let bookmarksWindow = app.windows["Bookmarks"]
        settingsWindow.popUpButtons["Settings"].click()
        settingsWindow.menuItems["Bookmarks"].click()
        if bookmarksWindow.sheets.buttons["Not Now"].exists {
            bookmarksWindow.sheets.buttons["Not Now"].click()
        }
        let duckduckgoBookmark =  bookmarksWindow.staticTexts["www.duckduckgo.com"]
        let stackOverflow =  bookmarksWindow.staticTexts["Stack Overflow - Where Developers Learn, Share, & Build Careers"]
        let privacySimplified = bookmarksWindow.staticTexts["DuckDuckGo — Privacy, simplified."]
        let wolfram = bookmarksWindow.staticTexts["Wolfram|Alpha: Computational Intelligence"]
        let news = bookmarksWindow.staticTexts["news"]
        let codes = bookmarksWindow.staticTexts["code"]
        let sports = bookmarksWindow.staticTexts["sports"]
        let gitHub = bookmarksWindow.staticTexts["DuckDuckGo · GitHub"]
        let spreadPrivacy = bookmarksWindow.staticTexts["www.spreadprivacy.com"]
        XCTAssertTrue(duckduckgoBookmark.exists)
        XCTAssertTrue(spreadPrivacy.exists)
        XCTAssertTrue(stackOverflow.exists)
        XCTAssertTrue(privacySimplified.exists)
        XCTAssertTrue(gitHub.exists)
        XCTAssertTrue(wolfram.exists)
        XCTAssertTrue(news.exists)
        XCTAssertTrue(codes.exists)
        XCTAssertTrue(sports.exists)
    }

    private func checkUnifiedFavorites() {
        let bookmarksWindow = app.windows["Bookmarks"]
        let gitHub = bookmarksWindow.staticTexts["DuckDuckGo · GitHub"]
        let spreadPrivacy = bookmarksWindow.staticTexts["www.spreadprivacy.com"]
        bookmarksWindow.outlines.staticTexts["Favorites"].click()
        XCTAssertTrue(gitHub.exists)
        XCTAssertTrue(spreadPrivacy.exists)
    }

    private func checkLogins() {
        let bookmarksWindow = app.windows["Bookmarks"]
        bookmarksWindow.buttons["NavigationBarViewController.optionsButton"].click()
        bookmarksWindow.menuItems["Autofill"].click()
        let elementsQuery = bookmarksWindow.popovers.scrollViews.otherElements
        elementsQuery.buttons["Da, Dax Login, daxthetest"].click()
        elementsQuery.buttons["Gi, Github, githubusername"].click()
        elementsQuery.buttons["My, mywebsite.com, mywebsite"].click()
        elementsQuery.buttons["St, StackOverflow, stacker"].click()
    }
}
