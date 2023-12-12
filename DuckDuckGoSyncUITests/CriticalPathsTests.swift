//
//  DuckDuckGoSyncUITests.swift
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

    func testCanCreateSyncAccount() throws {
        // Launch App
        let app = XCUIApplication()
        app.launch()

        // Set Internal User
        let menuBarsQuery = app.menuBars
        let debugMenuBarItem = menuBarsQuery.menuBarItems["Debug"]
        debugMenuBarItem.click()
        let internaluserstateMenuItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["internalUserState:"]/*[[".menuBarItems[\"Debug\"]",".menus",".menuItems[\"Internal User state\"]",".menuItems[\"internalUserState:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        internaluserstateMenuItem.click()

        // Go to Sync Set up
        let newTabWindow = app.windows["New Tab"]
        newTabWindow.children(matching: .button).element(boundBy: 4).click()
        newTabWindow/*@START_MENU_TOKEN@*/.menuItems["openPreferences:"]/*[[".buttons",".menus",".menuItems[\"Settings\"]",".menuItems[\"openPreferences:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        let settingsWindow = app.windows["Settings"]
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Sync & Backup"]/*[[".groups",".scrollViews.buttons[\"Sync & Backup\"]",".buttons[\"Sync & Backup\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()

        // Create Account
        let sheetsQuery = settingsWindow.sheets
        settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Sync and Back Up This Device"]/*[[".groups",".scrollViews.staticTexts[\"Sync and Back Up This Device\"]",".staticTexts[\"Sync and Back Up This Device\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Turn on Sync & Backup"]/*[[".groups.buttons[\"Turn on Sync & Backup\"]",".buttons[\"Turn on Sync & Backup\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Next"]/*[[".groups.buttons[\"Next\"]",".buttons[\"Next\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery.buttons["Done"].click()
        let syncEnabledElement = settingsWindow.staticTexts["Sync Enabled"]
        XCTAssertTrue(syncEnabledElement.exists, "Sync Enabled text is not visible")

        // Clean Up
        debugMenuBarItem.click()
        internaluserstateMenuItem.click()
        settingsWindow.swipeUp()
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Turn Off and Delete Server Data"]/*[[".groups",".scrollViews.buttons[\"Turn Off and Delete Server Data\"]",".buttons[\"Turn Off and Delete Server Data\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Delete Data"]/*[[".groups.buttons[\"Delete Data\"]",".buttons[\"Delete Data\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        let beginSync = settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Begin Syncing"]/*[[".groups",".scrollViews.staticTexts[\"Begin Syncing\"]",".staticTexts[\"Begin Syncing\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begyn Sync text is not visible")
    }

    func testCanRecoverSyncAccount() throws {
        // Launch App
        let app = XCUIApplication()
        app.launch()

        // Set Internal User
        let menuBarsQuery = app.menuBars
        let debugMenuBarItem = menuBarsQuery.menuBarItems["Debug"]
        debugMenuBarItem.click()
        let internaluserstateMenuItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["internalUserState:"]/*[[".menuBarItems[\"Debug\"]",".menus",".menuItems[\"Internal User state\"]",".menuItems[\"internalUserState:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        internaluserstateMenuItem.click()

        // Go to Sync Set up
        let newTabWindow = app.windows["New Tab"]
        newTabWindow.children(matching: .button).element(boundBy: 4).click()
        newTabWindow/*@START_MENU_TOKEN@*/.menuItems["openPreferences:"]/*[[".buttons",".menus",".menuItems[\"Settings\"]",".menuItems[\"openPreferences:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        let settingsWindow = app.windows["Settings"]
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Sync & Backup"]/*[[".groups",".scrollViews.buttons[\"Sync & Backup\"]",".buttons[\"Sync & Backup\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()

        // Create Account
        let sheetsQuery = settingsWindow.sheets
        settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Sync and Back Up This Device"]/*[[".groups",".scrollViews.staticTexts[\"Sync and Back Up This Device\"]",".staticTexts[\"Sync and Back Up This Device\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Turn on Sync & Backup"]/*[[".groups.buttons[\"Turn on Sync & Backup\"]",".buttons[\"Turn on Sync & Backup\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Copy Code"]/*[[".groups.buttons[\"Copy Code\"]",".buttons[\"Copy Code\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Next"]/*[[".groups.buttons[\"Next\"]",".buttons[\"Next\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery.buttons["Done"].click()
        let syncEnabledElement = settingsWindow.staticTexts["Sync Enabled"]
        XCTAssertTrue(syncEnabledElement.exists, "Sync Enabled text is not visible")

        // Log out
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Turn off Sync..."]/*[[".groups",".scrollViews.buttons[\"Turn off Sync...\"]",".buttons[\"Turn off Sync...\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Turn Off"]/*[[".groups.buttons[\"Turn Off\"]",".buttons[\"Turn Off\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()

        // Recover Account
        settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Recover Synced Data"]/*[[".groups",".scrollViews.staticTexts[\"Recover Synced Data\"]",".staticTexts[\"Recover Synced Data\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Get Started"]/*[[".groups.buttons[\"Get Started\"]",".buttons[\"Get Started\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Paste"]/*[[".groups.buttons[\"Paste\"]",".buttons[\"Paste\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Done"]/*[[".groups.buttons[\"Done\"]",".buttons[\"Done\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        XCTAssertTrue(syncEnabledElement.exists, "Sync Enabled text is not visible")

        // Clean Up
        debugMenuBarItem.click()
        internaluserstateMenuItem.click()
        settingsWindow.swipeUp()
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Turn Off and Delete Server Data"]/*[[".groups",".scrollViews.buttons[\"Turn Off and Delete Server Data\"]",".buttons[\"Turn Off and Delete Server Data\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Delete Data"]/*[[".groups.buttons[\"Delete Data\"]",".buttons[\"Delete Data\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        let beginSync = settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Begin Syncing"]/*[[".groups",".scrollViews.staticTexts[\"Begin Syncing\"]",".staticTexts[\"Begin Syncing\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begyn Sync text is not visible")
    }

    func testCanLoginToExistingSyncAccount() {
        //        guard let code = ProcessInfo.processInfo.environment["CODE"] else {
        //            XCTFail("CODE not set")
        //            return
        //        }

        let code = "eyJyZWNvdmVyeSI6eyJ1c2VyX2lkIjoiZGM2ZTMxZTctOTM3Mi00MjcwLTliOGMtNTlkYzczM2JhZmJhIiwicHJpbWFyeV9rZXkiOiJnR1FEaGU2UThnS00zTTVCZ0VOVHNwZTFYSWJGRVhqMSsxR2hNNDBmVGNJPSJ9fQ=="

        // Launch App
        let app = XCUIApplication()
        app.launch()

        // Set Internal User
        let menuBarsQuery = app.menuBars
        let debugMenuBarItem = menuBarsQuery.menuBarItems["Debug"]
        debugMenuBarItem.click()
        let internaluserstateMenuItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["internalUserState:"]/*[[".menuBarItems[\"Debug\"]",".menus",".menuItems[\"Internal User state\"]",".menuItems[\"internalUserState:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        internaluserstateMenuItem.click()

        // Go to Sync Set up
        let newTabWindow = app.windows["New Tab"]
        newTabWindow.children(matching: .button).element(boundBy: 4).click()
        newTabWindow/*@START_MENU_TOKEN@*/.menuItems["openPreferences:"]/*[[".buttons",".menus",".menuItems[\"Settings\"]",".menuItems[\"openPreferences:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        let settingsWindow = app.windows["Settings"]
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Sync & Backup"]/*[[".groups",".scrollViews.buttons[\"Sync & Backup\"]",".buttons[\"Sync & Backup\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()

        // Copy code to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(code, forType: .string)

        // Log In
        settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Sync with Another Device"]/*[[".groups",".scrollViews.staticTexts[\"Sync with Another Device\"]",".staticTexts[\"Sync with Another Device\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        let sheetsQuery = settingsWindow.sheets
        sheetsQuery/*@START_MENU_TOKEN@*/.staticTexts["Enter Code"]/*[[".groups.staticTexts[\"Enter Code\"]",".staticTexts[\"Enter Code\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Paste"]/*[[".groups.buttons[\"Paste\"]",".buttons[\"Paste\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Next"]/*[[".groups.buttons[\"Next\"]",".buttons[\"Next\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery.buttons["Done"].click()
        let secondDevice = settingsWindow/*@START_MENU_TOKEN@*/.images["SyncedDeviceMobile"]/*[[".groups",".scrollViews.images[\"SyncedDeviceMobile\"]",".images[\"SyncedDeviceMobile\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssertTrue(secondDevice.exists, "Original Device not visible")

        // Clean Up
        debugMenuBarItem.click()
        internaluserstateMenuItem.click()
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Turn off Sync..."]/*[[".groups",".scrollViews.buttons[\"Turn off Sync...\"]",".buttons[\"Turn off Sync...\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery/*@START_MENU_TOKEN@*/.buttons["Turn Off"]/*[[".groups.buttons[\"Turn Off\"]",".buttons[\"Turn Off\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        let beginSync = settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Begin Syncing"]/*[[".groups",".scrollViews.staticTexts[\"Begin Syncing\"]",".staticTexts[\"Begin Syncing\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begyn Sync text is not visible")
    }

    func testCanSyncData() {
        //        guard let code = ProcessInfo.processInfo.environment["CODE"] else {
        //            XCTFail("CODE not set")
        //            return
        //        }

        let code = "eyJyZWNvdmVyeSI6eyJ1c2VyX2lkIjoiYWY1YTZiMTEtNTYxZS00YTJiLWI1YzItYWQ0MTljMzIyMzJmIiwicHJpbWFyeV9rZXkiOiJlSkRIU3FwQ2Nxd2tyaFZudHZVWVlJdlIrTTYxRXQrbEJKcjFueUhucHNvPSJ9fQ=="

        // Launch App
        let app = XCUIApplication()
        app.launch()

        // Set Internal User
        let menuBarsQuery = app.menuBars
        let debugMenuBarItem = menuBarsQuery.menuBarItems["Debug"]
        debugMenuBarItem.click()
        let internaluserstateMenuItem = menuBarsQuery/*@START_MENU_TOKEN@*/.menuItems["internalUserState:"]/*[[".menuBarItems[\"Debug\"]",".menus",".menuItems[\"Internal User state\"]",".menuItems[\"internalUserState:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
        internaluserstateMenuItem.click()

        // Add Bookmarks and Favorite
        let newTabWindow = app.windows["New Tab"]
        newTabWindow.buttons["Options Button"].click()
        newTabWindow/*@START_MENU_TOKEN@*/.menuItems["openPreferences:"]/*[[".buttons[\"Options Button\"]",".menus",".menuItems[\"Settings\"]",".menuItems[\"openPreferences:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        let settingsWindow = app.windows["Settings"]
        settingsWindow/*@START_MENU_TOKEN@*/.popUpButtons["Settings"]/*[[".groups.popUpButtons[\"Settings\"]",".popUpButtons[\"Settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsWindow/*@START_MENU_TOKEN@*/.menuItems["Bookmarks"]/*[[".groups",".popUpButtons[\"Settings\"]",".menus.menuItems[\"Bookmarks\"]",".menuItems[\"Bookmarks\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        let bookmarksWindow = app.windows["Bookmarks"]
        bookmarksWindow/*@START_MENU_TOKEN@*/.buttons["  New Bookmark"]/*[[".splitGroups.buttons[\"  New Bookmark\"]",".buttons[\"  New Bookmark\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        let sheetsQuery = XCUIApplication().windows["Bookmarks"].sheets
        sheetsQuery.textFields["Title Text Field"].click()
        sheetsQuery.textFields["Title Text Field"].typeText("www.duckduckgo.com")
        sheetsQuery.textFields["URL Text Field"].click()
        sheetsQuery.textFields["URL Text Field"].typeText("www.duckduckgo.com")
        sheetsQuery.buttons["Add"].click()
        bookmarksWindow/*@START_MENU_TOKEN@*/.buttons["  New Bookmark"]/*[[".splitGroups.buttons[\"  New Bookmark\"]",".buttons[\"  New Bookmark\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        sheetsQuery.textFields["Title Text Field"].click()
        sheetsQuery.textFields["Title Text Field"].typeText("www.spreadprivacy.com")
        sheetsQuery.textFields["URL Text Field"].click()
        sheetsQuery.textFields["URL Text Field"].typeText("www.spreadprivacy.com")
        sheetsQuery.buttons["Add"].click()
        bookmarksWindow.staticTexts["www.spreadprivacy.com"].rightClick()
        bookmarksWindow/*@START_MENU_TOKEN@*/.menuItems["toggleBookmarkAsFavorite:"]/*[[".splitGroups",".menus",".menuItems[\"Add to Favorites\"]",".menuItems[\"toggleBookmarkAsFavorite:\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()

        // Add Login
//        bookmarksWindow.buttons["Options Button"].click()
//        bookmarksWindow/*@START_MENU_TOKEN@*/.menuItems["Autofill"]/*[[".buttons[\"Options Button\"]",".menus.menuItems[\"Autofill\"]",".menuItems[\"Autofill\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
//        bookmarksWindow/*@START_MENU_TOKEN@*/.popovers/*[[".buttons.popovers",".popovers"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.children(matching: .button).element(boundBy: 1).click()
//        bookmarksWindow/*@START_MENU_TOKEN@*/.popovers.menuItems["createNewLogin"]/*[[".buttons.popovers",".menus",".menuItems[\"Login\"]",".menuItems[\"createNewLogin\"]",".popovers"],[[[-1,4,1],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/.click()

        // Copy code to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(code, forType: .string)

        // Log In
        bookmarksWindow.splitGroups.children(matching: .popUpButton).element.click()
        bookmarksWindow/*@START_MENU_TOKEN@*/.menuItems["Settings"]/*[[".splitGroups",".popUpButtons",".menus.menuItems[\"Settings\"]",".menuItems[\"Settings\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Sync & Backup"]/*[[".groups",".scrollViews.buttons[\"Sync & Backup\"]",".buttons[\"Sync & Backup\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Sync with Another Device"]/*[[".groups",".scrollViews.staticTexts[\"Sync with Another Device\"]",".staticTexts[\"Sync with Another Device\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        let settingsSheetsQuery = settingsWindow.sheets
        settingsSheetsQuery/*@START_MENU_TOKEN@*/.staticTexts["Enter Code"]/*[[".groups.staticTexts[\"Enter Code\"]",".staticTexts[\"Enter Code\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery/*@START_MENU_TOKEN@*/.buttons["Paste"]/*[[".groups.buttons[\"Paste\"]",".buttons[\"Paste\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery/*@START_MENU_TOKEN@*/.buttons["Next"]/*[[".groups.buttons[\"Next\"]",".buttons[\"Next\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery.buttons["Done"].click()
        let secondDevice = settingsWindow/*@START_MENU_TOKEN@*/.images["SyncedDeviceMobile"]/*[[".groups",".scrollViews.images[\"SyncedDeviceMobile\"]",".images[\"SyncedDeviceMobile\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssertTrue(secondDevice.exists, "Original Device not visible")

        // Log Out
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Turn off Sync..."]/*[[".groups",".scrollViews.buttons[\"Turn off Sync...\"]",".buttons[\"Turn off Sync...\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery/*@START_MENU_TOKEN@*/.buttons["Turn Off"]/*[[".groups.buttons[\"Turn Off\"]",".buttons[\"Turn Off\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        let beginSync = settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Begin Syncing"]/*[[".groups",".scrollViews.staticTexts[\"Begin Syncing\"]",".staticTexts[\"Begin Syncing\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        beginSync.click()
        XCTAssertTrue(beginSync.exists, "Begyn Sync text is not visible")

        // Check Favorites not unified
        settingsWindow/*@START_MENU_TOKEN@*/.popUpButtons["Settings"]/*[[".groups.popUpButtons[\"Settings\"]",".popUpButtons[\"Settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsWindow/*@START_MENU_TOKEN@*/.menuItems["Bookmarks"]/*[[".groups",".popUpButtons[\"Settings\"]",".menus.menuItems[\"Bookmarks\"]",".menuItems[\"Bookmarks\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        bookmarksWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Favorites"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Favorites\"]",".staticTexts[\"Favorites\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        let gitHub = bookmarksWindow.staticTexts["DuckDuckGo · GitHub"]
        let spreadPrivacy = bookmarksWindow.staticTexts["www.spreadprivacy.com"]
        XCTAssertFalse(gitHub.exists)
        XCTAssertTrue(spreadPrivacy.exists)
        bookmarksWindow.outlines.staticTexts["Bookmarks"].click()

        // Remove Bookmarks
        bookmarksWindow.staticTexts["www.spreadprivacy.com"].rightClick()
        bookmarksWindow/*@START_MENU_TOKEN@*/.menus.menuItems["deleteBookmark:"]/*[[".splitGroups",".scrollViews.menus",".menuItems[\"Delete\"]",".menuItems[\"deleteBookmark:\"]",".menus"],[[[-1,4,2],[-1,1,2],[-1,0,1]],[[-1,4,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/.click()
        bookmarksWindow.staticTexts["www.duckduckgo.com"].rightClick()
        bookmarksWindow/*@START_MENU_TOKEN@*/.menus.menuItems["deleteBookmark:"]/*[[".splitGroups",".scrollViews.menus",".menuItems[\"Delete\"]",".menuItems[\"deleteBookmark:\"]",".menus"],[[[-1,4,2],[-1,1,2],[-1,0,1]],[[-1,4,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/.click()

        // Log In
        bookmarksWindow.splitGroups.children(matching: .popUpButton).element.click()
        bookmarksWindow/*@START_MENU_TOKEN@*/.menuItems["Settings"]/*[[".splitGroups",".popUpButtons",".menus.menuItems[\"Settings\"]",".menuItems[\"Settings\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsWindow/*@START_MENU_TOKEN@*/.buttons["Sync & Backup"]/*[[".groups",".scrollViews.buttons[\"Sync & Backup\"]",".buttons[\"Sync & Backup\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsWindow/*@START_MENU_TOKEN@*/.staticTexts["Sync with Another Device"]/*[[".groups",".scrollViews.staticTexts[\"Sync with Another Device\"]",".staticTexts[\"Sync with Another Device\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery/*@START_MENU_TOKEN@*/.staticTexts["Enter Code"]/*[[".groups.staticTexts[\"Enter Code\"]",".staticTexts[\"Enter Code\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery/*@START_MENU_TOKEN@*/.buttons["Paste"]/*[[".groups.buttons[\"Paste\"]",".buttons[\"Paste\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery/*@START_MENU_TOKEN@*/.buttons["Next"]/*[[".groups.buttons[\"Next\"]",".buttons[\"Next\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsSheetsQuery.buttons["Done"].click()
        XCTAssertTrue(secondDevice.exists, "Original Device not visible")
        let syncBackupScrollViewsQuery = settingsWindow/*@START_MENU_TOKEN@*/.scrollViews.containing(.staticText, identifier:"Sync & Backup")/*[[".groups",".scrollViews.containing(.button, identifier:\"Turn Off and Delete Server Data\")",".scrollViews.containing(.button, identifier:\"Save Your Recovery Code\")",".scrollViews.containing(.staticText, identifier:\"If you lose your device, you will need this recovery code to restore your synced data.\")",".scrollViews.containing(.staticText, identifier:\"Recovery\")",".scrollViews.containing(.staticText, identifier:\"Use the same favorite bookmarks on the new tab. Leave off to keep mobile and desktop favorites separate.\")",".scrollViews.containing(.staticText, identifier:\"Unify Favorites Across Devices\")",".scrollViews.containing(.staticText, identifier:\"Automatically download icons for synced bookmarks.\")",".scrollViews.containing(.staticText, identifier:\"Fetch Bookmark Icons\")",".scrollViews.containing(.staticText, identifier:\"Options\")",".scrollViews.containing(.button, identifier:\"Sync with Another Device\")",".scrollViews.containing(.image, identifier:\"SyncedDeviceMobile\")",".scrollViews.containing(.other, identifier:\"list of devices\")",".scrollViews.containing(.button, identifier:\"Details...\")",".scrollViews.containing(.button, identifier:\"list of devices\")",".scrollViews.containing(.staticText, identifier:\"list of devices\")",".scrollViews.containing(.image, identifier:\"SyncedDeviceDesktop\")",".scrollViews.containing(.image, identifier:\"list of devices\")",".scrollViews.containing(.staticText, identifier:\"Synced Devices\")",".scrollViews.containing(.staticText, identifier:\"Bookmarks and Saved Logins are currently in sync across your devices.\")",".scrollViews.containing(.button, identifier:\"Turn off Sync...\")",".scrollViews.containing(.staticText, identifier:\"Sync Enabled\")",".scrollViews.containing(.image, identifier:\"SolidCheckmark\")",".scrollViews.containing(.staticText, identifier:\"Sync & Backup\")"],[[[-1,23],[-1,22],[-1,21],[-1,20],[-1,19],[-1,18],[-1,17],[-1,16],[-1,15],[-1,14],[-1,13],[-1,12],[-1,11],[-1,10],[-1,9],[-1,8],[-1,7],[-1,6],[-1,5],[-1,4],[-1,3],[-1,2],[-1,1],[-1,0,1]],[[-1,23],[-1,22],[-1,21],[-1,20],[-1,19],[-1,18],[-1,17],[-1,16],[-1,15],[-1,14],[-1,13],[-1,12],[-1,11],[-1,10],[-1,9],[-1,8],[-1,7],[-1,6],[-1,5],[-1,4],[-1,3],[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        syncBackupScrollViewsQuery.children(matching: .switch).element(boundBy: 1).click()

        // Check Bookmarks
        settingsWindow/*@START_MENU_TOKEN@*/.popUpButtons["Settings"]/*[[".groups.popUpButtons[\"Settings\"]",".popUpButtons[\"Settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        settingsWindow/*@START_MENU_TOKEN@*/.menuItems["Bookmarks"]/*[[".groups",".popUpButtons[\"Settings\"]",".menus.menuItems[\"Bookmarks\"]",".menuItems[\"Bookmarks\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.click()
        bookmarksWindow.sheets/*@START_MENU_TOKEN@*/.buttons["Not Now"]/*[[".groups.buttons[\"Not Now\"]",".buttons[\"Not Now\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.click()
        let duckduckgoBookmark =  bookmarksWindow.staticTexts["www.duckduckgo.com"]
        let stackOverflow =  bookmarksWindow.staticTexts["Stack Overflow - Where Developers Learn, Share, & Build Careers"]
        let privacySimplified = bookmarksWindow.staticTexts["DuckDuckGo — Privacy, simplified."]
        let wolfram = bookmarksWindow.staticTexts["Wolfram|Alpha: Computational Intelligence"]
        let news = bookmarksWindow.staticTexts["news"]
        let codes = bookmarksWindow.staticTexts["code"]
        let sports = bookmarksWindow.staticTexts["sports"]
        XCTAssertTrue(duckduckgoBookmark.exists)
        XCTAssertTrue(spreadPrivacy.exists)
        XCTAssertTrue(stackOverflow.exists)
        XCTAssertTrue(privacySimplified.exists)
        XCTAssertTrue(gitHub.exists)
        XCTAssertTrue(wolfram.exists)
        XCTAssertTrue(news.exists)
        XCTAssertTrue(codes.exists)
        XCTAssertTrue(sports.exists)

        // Check Unified favorites
        bookmarksWindow/*@START_MENU_TOKEN@*/.outlines.staticTexts["Favorites"]/*[[".splitGroups",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"Favorites\"]",".staticTexts[\"Favorites\"]",".outlines"],[[[-1,5,2],[-1,1,2],[-1,0,1]],[[-1,5,2],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0,0]]@END_MENU_TOKEN@*/.click()
        XCTAssertTrue(gitHub.exists)
        XCTAssertTrue(spreadPrivacy.exists)

    }

}
