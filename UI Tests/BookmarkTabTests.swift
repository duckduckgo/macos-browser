//
//  BookmarkTabTests.swift
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

class BookmarkTabTests: DDGUITestCase {

    func testWhenAddingBookmarkFromSearchbar_ThenBookmarkAppearsInTab() throws {
        
        let app = XCUIApplication()
        
        //open the bookmark tab
        app.windows.children(matching: .button).element(boundBy: 4).click()
        app.windows.menuItems["openBookmarks:"].click()
        app.windows.popovers.children(matching: .button).element(boundBy: 2).click()
        
        //switch to the original tab
        let collectionViewsQuery = app.windows.collectionViews
        collectionViewsQuery.groups.containing(.image, identifier: "HomeFavicon").element.click()
        
        app.windows.textFields["Search or enter address"].typeText("duckduckgo.com\n")
        
        //create a bookmark
        app.windows.staticTexts["addressBarInactiveText"].forceHoverElement()
        app.windows.children(matching: .button).element(boundBy: 3).click()
        app.windows.popovers.buttons["Done"].click()
        
        //switch back to the bookmark tab
        collectionViewsQuery.groups.containing(.image, identifier: "Bookmarks").element.click()
        //verify that the bookmark shows up
        XCTAssertTrue(app.windows.tables.staticTexts["DuckDuckGo — Privacy, simplified."].exists)
    }
    
    func testWhenAddingBookmarkFromTab_ThenBookmarkCreated() throws {
        
        let app = XCUIApplication()
        
        // open the bookmarks tab
        app.windows.children(matching: .button).element(boundBy: 4).click()
        app.windows.menuItems["openBookmarks:"].click()
        app.windows.popovers.children(matching: .button).element(boundBy: 2).click()

        // create a new bookmark
        app.windows.buttons["  New Bookmark"].click()
        
        let favoritefilledborderCell = app.windows.outlines.cells.containing(.image, identifier:"FavoriteFilledBorder").element
        favoritefilledborderCell.typeText("Test Bookmark")
        
        let sheetsQuery = app.windows.sheets
        sheetsQuery.children(matching: .textField).element(boundBy: 0).click()
        favoritefilledborderCell.typeText("http://example.com")
        sheetsQuery.buttons["Add"].click()
        
        // verify that it appears in the bookmarks list
        app.windows.tables.staticTexts["Test Bookmark"].forceHoverElement()
        XCTAssertTrue(app.windows.tables.staticTexts["Test Bookmark – http://example.com"].exists)
    }
    
    func testWhenEditingBookmarkFromTab_ThenBookmarkUpdated() throws {
        
        let app = XCUIApplication()
        
        // open the bookmarks popup
        app.windows.children(matching: .button).element(boundBy: 4).click()
        app.windows.menuItems["openBookmarks:"].click()
        app.windows.popovers.children(matching: .button).element(boundBy: 2).click()
        
        app.windows.buttons["  New Bookmark"].click()
        
        let favoritefilledborderCell = app.windows.outlines.cells.containing(.image, identifier:"FavoriteFilledBorder").element
        favoritefilledborderCell.typeText("Test 1")
        
        let sheetsQuery = app.windows.sheets
        sheetsQuery.children(matching: .textField).element(boundBy: 0).click()
        favoritefilledborderCell.typeText("http://example.com")
        
        app.windows.sheets.buttons["Add"].click()
        app.windows.splitGroups.tables.staticTexts["Test 1"].forceHoverElement()
        
        app.windows.splitGroups.tables.groups.children(matching: .button).element.click()
        app.windows.menuItems["editBookmark:"].click()
        
        let group = app.windows.splitGroups.tables.cells.children(matching: .group).element(boundBy: 1)
        group.children(matching: .textField).element(boundBy: 0).click()
        favoritefilledborderCell.typeKey(.delete, modifierFlags:[])
        favoritefilledborderCell.typeText("2")
        
        let textField = group.children(matching: .textField).element(boundBy: 1)
        textField.click()
        textField.doubleClick()
        favoritefilledborderCell.typeText("duckduckgo.com")
        
        let automatictablecolumnidentifier0Table = app.windows.tables.containing(.tableColumn, identifier:"AutomaticTableColumnIdentifier.0").element
        automatictablecolumnidentifier0Table.click()
        app.windows.splitGroups.tables.staticTexts["Test 2"].forceHoverElement()
        app.windows.tables.staticTexts["Test 2 – http://duckduckgo.com"].rightClick()
        
    }

}
