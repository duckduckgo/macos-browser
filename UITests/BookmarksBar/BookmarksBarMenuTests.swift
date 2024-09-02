//
//  BookmarksBarMenuTests.swift
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

import Common
import XCTest

class BookmarksBarMenuTests: BookmarksBarTestsBase {

    override func runSetupOnceIfNeeded() -> Bool {
        guard super.runSetupOnceIfNeeded() else { return false }

        resetBookmarks()
        importBookmarks(andShowBookmarksBar: true)

        return true
    }

    // MARK: - Tests

    @MainActor func test_bookmarksBar_whenItemsReordered_itemsPlacementIsUpdated() async throws {
        let firstBookmark = bookmarksBarItems[0]
        let secondBookmark = bookmarksBarItems[1]

        let firstBookmarkTitle = firstBookmark.title
        let secondBookmarkTitle = secondBookmark.title

        // drag the first item to the second item position
        firstBookmark.press(forDuration: 0.1, thenDragTo: secondBookmark.normalizedCoordinate, withVelocity: .fast, thenHoldForDuration: 0.1)

        // check new items titles after reordering
        XCTAssertEqual(bookmarksBarItems[0].title, secondBookmarkTitle)
        XCTAssertEqual(bookmarksBarItems[1].title, firstBookmarkTitle)
    }

    @MainActor func test_bookmarksBar_whenLongFolderIsClicked_menuPositionedBelowButtonAndAllItemsFit() async throws {
        // Click folder element on the Bookmarks Bar
        let folderItem = bookmarksBarItems[title: "Long folder"]
        let overflownFolderItem = bookmarksBarItems[title: "Overflown folder"]
        XCTAssertTrue(folderItem.waitForExistence(timeout: UITests.Timeouts.elementExistence), "`Long folder` item not found")
        XCTAssertTrue(overflownFolderItem.waitForExistence(timeout: UITests.Timeouts.elementExistence), "`Overflown folder` item not found")
        folderItem.clickAtCoordinate()

        XCTContext.log("folderItem.frame", folderItem.frame)

        // Expect Bookmarks Menu popover to appear
        var folderMenu = bookmarksBarCollectionView.popovers.firstMatch
        XCTAssertTrue(
            folderMenu.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Could not get Folder Bookmarks menu popover"
        )

        // Validate popover positioning
        XCTContext.log("folderMenu.frame", folderMenu.frame)
        
        // TODO: validate the menu is positioned below the button and the popover fits all the items

        let menuItemsCount = folderMenu.outlines.staticTexts.count
        let firstItem = folderMenu.outlines.staticTexts.element(boundBy: 0)
        let lastElement = folderMenu.outlines.staticTexts.element(boundBy: menuItemsCount - 1)
        XCTContext.log("menuItemsCount", menuItemsCount)
        XCTContext.log("firstItem.frame", firstItem.frame)
        XCTContext.log("lastElement.frame", lastElement.frame)

//        error    18:12:22.586560+0600    UI Tests-Runner    folderItem.frame (1121.0, 453.0, 69.0, 15.0)
//        error    18:12:23.697834+0600    UI Tests-Runner    folderMenu.frame (1084.0, 460.0, 500.0, 477.0) maxY = 937
//        error    18:12:23.796046+0600    UI Tests-Runner    firstItem.frame (1142.0, 489.0, 35.0, 16.0)
//        error    18:12:23.836750+0600    UI Tests-Runner    lastElement.frame (1111.0, 892.0, 114.0, 16.0) maxY = 918

        overflownFolderItem.normalizedCoordinate.hover()

        folderMenu = bookmarksBarCollectionView.popovers.firstMatch
        XCTContext.log("folderMenu.frame", folderMenu.frame)

        let menuItemsCount2 = folderMenu.outlines.staticTexts.count
        let firstItem2 = folderMenu.outlines.staticTexts.element(boundBy: 0)
        let item20 = folderMenu.outlines.staticTexts.element(boundBy: 20)
        let item30 = folderMenu.outlines.staticTexts.element(boundBy: 30)
        let item40 = folderMenu.outlines.staticTexts.element(boundBy: 40)
        let prePreLastElement = folderMenu.outlines.staticTexts.element(boundBy: menuItemsCount - 3)
        let preLastElement = folderMenu.outlines.staticTexts.element(boundBy: menuItemsCount - 2)
        let lastElement2 = folderMenu.outlines.staticTexts.element(boundBy: menuItemsCount - 1)
        XCTContext.log("menuItemsCount2", menuItemsCount2)

        XCTContext.log("firstItem2.frame", firstItem2.frame)
        XCTContext.log("item20", item20.value, item20.frame)
        XCTContext.log("item30", item30.value, item30.frame)
        XCTContext.log("item40", item40.value, item40.frame)
        XCTContext.log("prePreLastElement", prePreLastElement.value, prePreLastElement.frame)
        XCTContext.log("preLastElement", preLastElement.value, preLastElement.frame)
        XCTContext.log("lastElement2", lastElement2.value, lastElement2.frame)

//        XCUIApplication().windows["New Tab"]/*@START_MENU_TOKEN@*/.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"].popovers/*[[".scrollViews.collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]",".groups.popovers",".popovers",".collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]"],[[[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/.scrollViews.children(matching: .outline).element.typeKey("c", modifierFlags:[.command, .option])

//       folderItem.frame (1121.0, 453.0, 69.0, 15.0)
//       folderMenu.frame (1084.0, 460.0, 500.0, 477.0)
//       menuItemsCount 15
//       firstItem.frame (1142.0, 489.0, 35.0, 16.0)
//       lastElement.frame (1111.0, 892.0, 114.0, 16.0)

//       folderMenu.frame (1293.0, 460.0, 500.0, 891.0) // MaxY = 1351
//       menuItemsCount2 46
//       firstItem2.frame (1351.0, 489.0, 415.0, 16.0)
//       item20.frame (1351.0, 1049.0, 45.0, 16.0)
//       item30.frame (1351.0, 1329.0, 394.0, 16.0)
//       item40.frame (1351.0, 1609.0, 45.0, 16.0) // MaxY = 1625
//       lastElement2.frame (1351.0, 881.0, 372.0, 16.0)



//        let parent = try folderItem.value(forAccessibilityAttribute: "AXParent")
//        XCTContext.log("parent", parent)

//        let newTabWindow = XCUIApplication().windows["New Tab"]
//        newTabWindow/*@START_MENU_TOKEN@*/.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"].popovers.outlines.cells.containing(.staticText, identifier:"OK J1DNE4")/*[[".scrollViews.collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]",".groups.popovers",".scrollViews.outlines",".outlineRows",".cells.containing(.staticText, identifier:\"– www.example.com\/VQtRr537Tu\")",".cells.containing(.staticText, identifier:\"OK J1DNE4\")",".outlines",".popovers",".collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]"],[[[-1,8,1],[-1,0,1]],[[-1,7,2],[-1,1,2]],[[-1,6,3],[-1,2,3]],[[-1,5],[-1,4],[-1,3,4]],[[-1,5],[-1,4]]],[0,0,0,0]]@END_MENU_TOKEN@*/.children(matching: .button).element.click()
//        newTabWindow/*@START_MENU_TOKEN@*/.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"]/*[[".scrollViews.collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]",".collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.otherElements.children(matching: .group).element(boundBy: 3).children(matching: .popover).element.click()
//        newTabWindow.click()
//        newTabWindow.children(matching: .button).element(boundBy: 0).click()
//        newTabWindow.click()
//        newTabWindow.click()
//        newTabWindow.click()
//        newTabWindow.click()
//        newTabWindow.click()
//        newTabWindow.click()

//        error    16:02:46.630892+0600    UI Tests-Runner    folderItem.frame (1121.0, 453.0, 69.0, 15.0) "Long folder" StaticText[0.50, 0.50]
//        error    16:02:47.746969+0600    UI Tests-Runner    folderMenu.frame (1084.0, 460.0, 500.0, 477.0) Popover at {{1084.0, 460.0}, {500.0, 477.0}}[0.50, 0.50]

//        error    17:38:18.193547+0600    UI Tests-Runner    folderItem.frame (1121.0, 453.0, 69.0, 15.0) "Long folder" StaticText[0.50, 0.50]
//        error    17:38:19.294699+0600    UI Tests-Runner    folderMenu.frame (1084.0, 460.0, 500.0, 477.0) Popover at {{1084.0, 460.0}, {500.0, 477.0}}[0.50, 0.50]

//        XCUIApplication().windows["New Tab"].popovers.outlines.staticTexts["HU8OqzZp3PwcLv MHdtQyEFhdNXbkJQzyR60MievxRZtz"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
//        
//        let window = XCUIApplication().windows["404 - Not Found"]
//        window.children(matching: .button).element(boundBy: 0).click()
//        window.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"].click()
        
//        let newTabWindow = XCUIApplication().windows["New Tab"]
//        newTabWindow.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"].popovers.outlines.staticTexts["lxyaV422f6WJlUxzIyKimdMILGxtcVawHguwjNjfrxedDE0Rw"].click()
//        newTabWindow/*@START_MENU_TOKEN@*/.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"].popovers.outlines.staticTexts["G5 sTEzMvFJNYfSbzgsGRjMwzWJICY0ESIyg9f9mcIP6 NYDD68ynZm4w1rzBgGGFXp3RSrxFFOV2FwAmDK7u"]/*[[".scrollViews.collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]",".groups.popovers",".scrollViews.outlines",".outlineRows",".cells.staticTexts[\"G5 sTEzMvFJNYfSbzgsGRjMwzWJICY0ESIyg9f9mcIP6 NYDD68ynZm4w1rzBgGGFXp3RSrxFFOV2FwAmDK7u\"]",".staticTexts[\"G5 sTEzMvFJNYfSbzgsGRjMwzWJICY0ESIyg9f9mcIP6 NYDD68ynZm4w1rzBgGGFXp3RSrxFFOV2FwAmDK7u\"]",".outlines",".popovers",".collectionViews[\"BookmarksBarViewController.bookmarksBarCollectionView\"]"],[[[-1,8,1],[-1,0,1]],[[-1,7,2],[-1,1,2]],[[-1,6,3],[-1,2,3]],[[-1,5],[-1,4],[-1,3,4]],[[-1,5],[-1,4]]],[0,0,0,0]]@END_MENU_TOKEN@*/.click()
//        newTabWindow.popovers.outlines.popovers.outlines.staticTexts["JCKIRpbONCUQ07lKYViz9YhIVUq4spo9OMx7Lucu3WyFX7l2CCDZmph pHFoOOLUJBMJCG31B"].click()


//        bookmarksBarCollectionView.popovers.staticTexts["lxyaV422f6WJlUxzIyKimdMILGxtcVawHguwjNjfrxedDE0Rw"].click()
    }

    // TODO: Overflown folder should show scrollers and expand up on scroll
    // TODO: scroll buttons hover
    // TODO: Reordering items between menus

}

extension BookmarksBarMenuTests {

    struct BookmarksBarItems {
        let bookmarksBarCollectionView: XCUIElement
        subscript(index: Int) -> XCUIElement {
            bookmarksBarCollectionView.staticTexts.element(boundBy: index)
        }
        subscript(title title: String) -> XCUIElement {
            bookmarksBarCollectionView.staticTexts.element(matching: NSPredicate(format: "value = %@", title))
        }
    }
    var bookmarksBarItems: BookmarksBarItems {
        BookmarksBarItems(bookmarksBarCollectionView: bookmarksBarCollectionView)
    }

}
