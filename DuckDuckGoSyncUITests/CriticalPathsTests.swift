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

//    func testCanSyncData() {
//        
//        
//        let app = XCUIApplication()
//        app.windows["New Tab"].textFields["Search or enter address"].typeText("duckduck")
//        
//        let historysuggestionCell = app/*@START_MENU_TOKEN@*/.tables.cells.containing(.image, identifier:"HistorySuggestion").element/*[[".dialogs",".scrollViews.tables",".tableRows.cells.containing(.image, identifier:\"HistorySuggestion\").element",".cells.containing(.image, identifier:\"HistorySuggestion\").element",".tables"],[[[-1,4,2],[-1,1,2],[-1,0,1]],[[-1,4,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/
//        historysuggestionCell.typeText("go.c")
//        historysuggestionCell.typeText("om")
//        historysuggestionCell.typeText("\r")
//        
//        let duckduckgoPrivacySimplifiedWindow = app.windows["DuckDuckGo — Privacy, simplified."]
//        duckduckgoPrivacySimplifiedWindow.children(matching: .button).element(boundBy: 3).click()
//        duckduckgoPrivacySimplifiedWindow/*@START_MENU_TOKEN@*/.popovers.buttons["bookmark.add.done.button"]/*[[".buttons.popovers",".buttons[\"Done\"]",".buttons[\"bookmark.add.done.button\"]",".popovers"],[[[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/.click()
//  
//    }

}
