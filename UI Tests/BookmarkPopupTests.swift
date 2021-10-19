//
//  BookmarksTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Cocoa

class BookmarkPopupTests: DDGUITestCase {

    func testWhenAddingBookmarkFromSearchbar_ThenBookmarkAppearsInPopover() throws {
        /*
         Loads duckduckgo.com, adds a bookmark, opens a new tab, opens the bookmark from the bookmarks popover, and verifies that duckduckgo.com gets loaded.
         */
        
        let app = XCUIApplication()
        
        app.windows.textFields["Search or enter address"].typeText("duckduckgo.com\n")
        
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()
        sleep(2)
        app.windows.children(matching: .button).element(boundBy: 3).forceClickElement()
        
        app.windows.popovers.buttons["Done"].click()
        app.windows.collectionViews.otherElements.children(matching: .group)
            .element(boundBy: 1).children(matching: .button).element.forceClickElement()
        app.windows.children(matching: .button).element(boundBy: 4).forceClickElement()
        app.windows.menuItems["openBookmarks:"].click()
        app.windows.popovers.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].forceClickElement()
        app.windows.containing(.staticText, identifier: "Search or enter address").element.forceClickElement()
        
        XCTAssertEqual(app.windows.textFields["Search or enter address"].firstMatch.value as? String, "https://duckduckgo.com/")
    }
    
    func testWhenAddingBookmarkFromMenu_ThenBookmarkAppearsInPopover() throws {
        
        let app = XCUIApplication()
        let windowsQuery = app.windows
        windowsQuery.textFields["Search or enter address"].typeText("duckduckgo.com\n")
        
        app.menuBars.menuBarItems["Bookmarks"].click()
        
        app.menuBars.menuItems["Bookmark this page..."].click()
        
        app.windows.collectionViews.otherElements.children(matching: .group)
            .element(boundBy: 1).children(matching: .button).element.forceClickElement()
        
        windowsQuery.children(matching: .button).element(boundBy: 4).forceClickElement()
        sleep(2)
        windowsQuery.menuItems["openBookmarks:"].click()
        windowsQuery.popovers.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].forceClickElement()
        
        app.windows.containing(.staticText, identifier: "Search or enter address").element.forceClickElement()
        
        XCTAssertEqual(app.windows.textFields["Search or enter address"].firstMatch.value as? String, "https://duckduckgo.com/")
    }
    
    func testWhenDeletingBookmarkFromPopover_ThenBookmarkRemoved() throws {
        let app = XCUIApplication()
        let windowsQuery = app.windows
        
        // create the first bookmark
        windowsQuery.textFields["Search or enter address"].typeText("duckduckgo.com\n")
        
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()
        sleep(2)
        app.windows.children(matching: .button).element(boundBy: 3).forceClickElement()
        app.windows.popovers.buttons["Done"].click()
        
        // new tab
        let elementsQuery = app.windows.collectionViews.otherElements
        elementsQuery.children(matching: .group).element(boundBy: 1).children(matching: .button).element.forceClickElement()
        
        // create the second bookmark
        windowsQuery.textFields["Search or enter address"].typeText("example.com\n")
        
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()
        sleep(2)
        app.windows.children(matching: .button).element(boundBy: 3).forceClickElement()
        app.windows.popovers.buttons["Done"].click()
        
        // move mouse off the address bar
        app.windows.collectionViews.otherElements.children(matching: .group).element(boundBy: 1).forceHoverElement()
        sleep(2)
        // open the popover and delete the first bookmark
        let button2 = windowsQuery.children(matching: .button).element(boundBy: 4)
        button2.forceClickElement()
        
        let openbookmarksMenuItem = app.windows.menuItems["openBookmarks:"]
        openbookmarksMenuItem.click()
        
        let popoversQuery = windowsQuery.popovers
        popoversQuery.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].rightClick()
        popoversQuery.menus.menuItems["deleteBookmark:"].click()
        
        // new tab
        elementsQuery.children(matching: .group).element(boundBy: 2).children(matching: .button).element.forceClickElement()
        
        // open the popup again
        button2.forceClickElement()
        openbookmarksMenuItem.click()
        
        // ensure that the first bookmark has been removed and the second bookmark remains
        XCTAssertFalse(app.windows.popovers.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].exists)
        XCTAssertTrue(popoversQuery.outlines.staticTexts["Example Domain"].exists)
        popoversQuery.outlines.staticTexts["Example Domain"].forceClickElement()
        
        // make sure the second bookmark is clickable
        app.windows.containing(.staticText, identifier: "addressBarInactiveText").element.forceClickElement()
        XCTAssertEqual(app.windows.textFields["Search or enter address"].firstMatch.value as? String, "http://example.com/")
    }
    
    func testAddingFavoriteFromPopover_ThenBookmarkFavorited () {
        let app = XCUIApplication()
        
        // make a bookmark
        app.windows.textFields["Search or enter address"].typeText("duckduckgo.com\n")

        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()

        app.windows.children(matching: .button).element(boundBy: 3).click()
        app.windows.popovers.buttons["Done"].click()
        
        // move mouse off the address bar
        app.windows.collectionViews.otherElements.children(matching: .group).element(boundBy: 1).forceHoverElement()
        
        // open the popup
        app.windows.children(matching: .button).element(boundBy: 4).click()
        app.windows.menuItems["openBookmarks:"].click()
        let popoversQuery = app.windows.popovers
        
        // favorite the bookmark
        popoversQuery.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].rightClick()
        popoversQuery.menus.menuItems["toggleBookmarkAsFavorite:"].click()
        
        // try clicking on the disclosure triangle for favorites
        popoversQuery.outlines.disclosureTriangles["NSOutlineViewDisclosureButtonKey"].click()
        
        // make sure the context menu title is updated
        popoversQuery.outlines.children(matching: .outlineRow).element(boundBy: 1).staticTexts["DuckDuckGo — Privacy, simplified."].rightClick()
        XCTAssertEqual(popoversQuery.menus.menuItems["toggleBookmarkAsFavorite:"].title, "Remove from Favorites")
    }
    
    func testCreatingFolderAndMovingBookmarkInPopover_ThenBookmarkMoved () {
        let app = XCUIApplication()
        app.windows.textFields["Search or enter address"].typeText("duckduckgo.com\n")

        // create a folder
        let button = app.windows.children(matching: .button).element(boundBy: 4)
        button.click()
        let openbookmarksMenuItem = app.windows.menuItems["openBookmarks:"]
        openbookmarksMenuItem.click()
        app.windows.popovers.children(matching: .button).element(boundBy: 1).click()
        app.dialogs["Untitled"].children(matching: .textField).element.typeText("Test Folder\n")

        // create a bookmark
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()

        app.windows.children(matching: .button).element(boundBy: 3).click()
        app.windows.popovers.buttons["Done"].click()
        
        // move mouse off the address bar
        app.windows.collectionViews.otherElements.children(matching: .group).element(boundBy: 1).forceHoverElement()
        
        // open the bookmarks popup
        app.windows.children(matching: .button).element(boundBy: 4).click()
        openbookmarksMenuItem.click()
        
        let popoversQuery = app.windows.popovers
        let duckduckgoPrivacySimplifiedStaticText = popoversQuery.outlines.staticTexts["DuckDuckGo — Privacy, simplified."]
        let folderText = popoversQuery.outlines.staticTexts["Test Folder"]
        
        // drag the bookmark into the folder
        duckduckgoPrivacySimplifiedStaticText.press(forDuration: 1, thenDragTo: folderText)
        
        let duckduckgoPrivacySimplifiedWebView = app.windows.webViews["DuckDuckGo — Privacy, simplified."]
        duckduckgoPrivacySimplifiedWebView.click()
        
        button.click()
        openbookmarksMenuItem.click()
        
        // bookmark shouldn't be visible
        XCTAssertFalse(duckduckgoPrivacySimplifiedStaticText.isHittable)
        popoversQuery.outlines.disclosureTriangles["NSOutlineViewDisclosureButtonKey"].click()
        // open the folder and verify that the bookmark is visible now
        XCTAssertTrue(duckduckgoPrivacySimplifiedStaticText.isHittable)
        duckduckgoPrivacySimplifiedStaticText.click()
    }
    
    func testRenamingFolderInPopover_thenFolderRenamed() {
        
        let app = XCUIApplication()
        let windowsQuery = app.windows
        let button = windowsQuery.children(matching: .button).element(boundBy: 4)
        button.click()
        
        let openbookmarksMenuItem = windowsQuery.menuItems["openBookmarks:"]
        openbookmarksMenuItem.click()
        
        let popoversQuery = windowsQuery.popovers
        popoversQuery.children(matching: .button).element(boundBy: 1).click()
        
        let textField = app.dialogs["Untitled"].children(matching: .textField).element
        textField.typeText("Original folder name\n")
        button.click()
        openbookmarksMenuItem.click()
        XCTAssertNotNil(popoversQuery.staticTexts["Original folder name"].firstMatch)
        
        popoversQuery.outlines.staticTexts["Original folder name"].rightClick()
        popoversQuery.menus.menuItems["renameFolder:"].click()
        textField.typeText("New folder name\n")
        button.click()
        openbookmarksMenuItem.click()
        XCTAssertFalse(popoversQuery.staticTexts["Original folder name"].exists)
        XCTAssertTrue(popoversQuery.staticTexts["New folder name"].exists)
    }
}
