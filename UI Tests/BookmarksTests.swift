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

class BookmarksTests: DDGUITestCase {

    func testWhenAddingBookmarkFromSearchbar_ThenBookmarkAppearsInPopover() throws {
        /*
         Loads duckduckgo.com, adds a bookmark, opens a new tab, opens the bookmark from the bookmarks popover, and verifies that duckduckgo.com gets loaded.
         */
        
        let app = XCUIApplication()
        
        app.windows.textFields["Search or enter address"].typeText("duckduckgo.com\n")
        
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()
                
        app.windows.children(matching: .button).element(boundBy: 3).click()
        
        app.windows.popovers.buttons["Done"].click()
        app.windows.collectionViews.otherElements.children(matching: .group).element(boundBy: 1).children(matching: .button).element.click()
        app.windows.children(matching: .button).element(boundBy: 4).click()
        app.windows.menuItems["openBookmarks:"].click()
        app.windows.popovers.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].click()
        app.windows.containing(.staticText, identifier: "Search or enter address").element.click()
        
        XCTAssertEqual(app.windows.textFields["Search or enter address"].firstMatch.value as? String, "https://duckduckgo.com/")
    }
    
    func testWhenAddingBookmarkFromMenu_ThenBookmarkAppearsInPopover() throws {
        
        let app = XCUIApplication()
        let windowsQuery = app.windows
        windowsQuery.textFields["Search or enter address"].typeText("duckduckgo.com\n")
        
        app.menuBars.menuBarItems["Bookmarks"].click()
        
        app.menuBars.menuItems["Bookmark this page..."].click()
        
        app.windows.collectionViews.otherElements.children(matching: .group).element(boundBy: 1).children(matching: .button).element.click()
        
        windowsQuery.children(matching: .button).element(boundBy: 4).click()
        windowsQuery.menuItems["openBookmarks:"].click()
        windowsQuery.popovers.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].click()
        
        app.windows.containing(.staticText, identifier: "Search or enter address").element.click()
        
        XCTAssertEqual(app.windows.textFields["Search or enter address"].firstMatch.value as? String, "https://duckduckgo.com/")
    }
    
    func testWhenDeletingBookmarkFromPopup_ThenBookmarkRemoved() throws {
        let app = XCUIApplication()
        let windowsQuery = app.windows
        
        // create the first bookmark
        windowsQuery.textFields["Search or enter address"].typeText("duckduckgo.com\n")
        
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()
        app.windows.children(matching: .button).element(boundBy: 3).click()
        app.windows.popovers.buttons["Done"].click()
        
        // new tab
        let elementsQuery = app.windows.collectionViews.otherElements
        elementsQuery.children(matching: .group).element(boundBy: 1).children(matching: .button).element.click()
        
        // create the second bookmark
        windowsQuery.textFields["Search or enter address"].typeText("example.com\n")
        
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()
        app.windows.children(matching: .button).element(boundBy: 3).click()
        app.windows.popovers.buttons["Done"].click()
        
        // move mouse off the address bar
        app.windows.collectionViews.otherElements.children(matching: .group).element(boundBy: 1).forceHoverElement()
        
        // open the popover and delete the first bookmark
        let button2 = windowsQuery.children(matching: .button).element(boundBy: 4)
        button2.click()
        
        let openbookmarksMenuItem = app.windows.menuItems["openBookmarks:"]
        openbookmarksMenuItem.click()
        
        let popoversQuery = windowsQuery.popovers
        popoversQuery.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].rightClick()
        popoversQuery.menus.menuItems["deleteBookmark:"].click()
        
        // new tab
        elementsQuery.children(matching: .group).element(boundBy: 2).children(matching: .button).element.click()
        
        // open the popup again
        button2.click()
        openbookmarksMenuItem.click()
        
        // ensure that the first bookmark has been removed and the second bookmark remains
        XCTAssertFalse(app.windows.popovers.outlines.staticTexts["DuckDuckGo — Privacy, simplified."].exists)
        XCTAssertTrue(popoversQuery.outlines.staticTexts["Example Domain"].exists)
        popoversQuery.outlines.staticTexts["Example Domain"].click()
        
        // make sure the second bookmark is clickable
        app.windows.containing(.staticText, identifier: "addressBarInactiveText").element.click()
        XCTAssertEqual(app.windows.textFields["Search or enter address"].firstMatch.value as? String, "http://example.com/")
    }
}
