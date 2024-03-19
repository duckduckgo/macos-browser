//
//  ContextualMenuTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class ContextualMenuTests: XCTestCase {

    func testWhenAskingBookmarkMenuItemsAndIsNotFavoriteThenItShouldReturnTheItemsInTheCorrectOrder() {
        // GIVEN
        let isFavorite = false

        // WHEN
        let items = ContextualMenu.bookmarkMenuItems(isFavorite: isFavorite)

        // THEN
        XCTAssertEqual(items.count, 12)
        assertMenu(item: items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)))
        assertMenu(item: items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)))
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)))
        assertMenu(item: items[4], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)))
        assertMenu(item: items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)))
        assertMenu(item: items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)))
        assertMenu(item: items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)))
        assertMenu(item: items[9], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)))
        assertMenu(item: items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))

    }

    func testWhenAskingBookmarkMenuItemsAndIsFavoriteThenItShouldReturnTheItemsInTheCorrectOrder() {
        // GIVEN
        let isFavorite = true

        // WHEN
        let items = ContextualMenu.bookmarkMenuItems(isFavorite: isFavorite)

        // THEN
        assertMenu(item: items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)))
        assertMenu(item: items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)))
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.removeFromFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)))
        assertMenu(item: items[4], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)))
        assertMenu(item: items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)))
        assertMenu(item: items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)))
        assertMenu(item: items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)))
        assertMenu(item: items[9], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)))
        assertMenu(item: items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    func testWhenAskingFolderItemThenItShouldReturnTheItemsInTheCorrectOrders() {
        // WHEN
        let items = ContextualMenu.folderMenuItems()

        // THEN
        XCTAssertEqual(items.count, 9)
        assertMenu(item: items[0], withTitle: UserText.openAllInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)))
        assertMenu(item: items[1], withTitle: UserText.openAllTabsInNewWindow, selector: #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)))
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.editBookmark, selector: #selector(FolderMenuItemSelectors.editFolder(_:)))
        assertMenu(item: items[4], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(FolderMenuItemSelectors.deleteFolder(_:)))
        assertMenu(item: items[5], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(FolderMenuItemSelectors.moveToEnd(_:)))
        assertMenu(item: items[6], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[7], withTitle: UserText.addFolder, selector: #selector(FolderMenuItemSelectors.newFolder(_:)))
        assertMenu(item: items[8], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(FolderMenuItemSelectors.manageBookmarks(_:)))
    }

    func testWhenCreateMenuForEmptySelectionThenItReturnsAMenuWithAddFolderOnly() throws {
        // WHEN
        let menu = ContextualMenu.menu(for: [])

        // THEN
        XCTAssertEqual(menu?.items.count, 1)
        let menuItem = try XCTUnwrap(menu?.items.first)
        assertMenu(item: menuItem, withTitle: UserText.addFolder, selector: #selector(FolderMenuItemSelectors.newFolder(_:)))
    }

    func testWhenCreateMenuForBookmarkWithoutParentThenReturnsAMenuWithTheBookmarkMenuItems() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false)

        // WHEN
        let menu = ContextualMenu.menu(for: [bookmark])

        // THEN
        let items = try XCTUnwrap(menu?.items)
        XCTAssertEqual(items.count, 12)
        assertMenu(item: items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
        assertMenu(item: items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
        assertMenu(item: items[4], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
        assertMenu(item: items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
        assertMenu(item: items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
        assertMenu(item: items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: BookmarkEntityInfo(entity: bookmark, parent: nil))
        assertMenu(item: items[9], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)))
        assertMenu(item: items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    func testWhenCreateMenuForBookmarkWithParentThenReturnsAMenuWithTheBookmarkMenuItems() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false, parentFolderUUID: "A")
        let parent = BookmarkFolder(id: "A", title: "Folder", children: [bookmark])
        let parentNode = BookmarkNode(representedObject: parent, parent: nil)
        let node = BookmarkNode(representedObject: bookmark, parent: parentNode)

        // WHEN
        let menu = ContextualMenu.menu(for: [node])

        // THEN
        let items = try XCTUnwrap(menu?.items)
        XCTAssertEqual(items.count, 12)
        assertMenu(item: items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
        assertMenu(item: items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
        assertMenu(item: items[4], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
        assertMenu(item: items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
        assertMenu(item: items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
        assertMenu(item: items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: BookmarkEntityInfo(entity: bookmark, parent: parent))
        assertMenu(item: items[9], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)), representedObject: parent)
        assertMenu(item: items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    func testWhenCreateMenuForFolderNodeThenReturnsAMenuWithTheFolderMenuItems() throws {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: "Child")
        let parent = BookmarkFolder(id: "1", title: "Parent", children: [folder])
        let parentNode = BookmarkNode(representedObject: parent, parent: nil)
        let node = BookmarkNode(representedObject: folder, parent: parentNode)

        // WHEN
        let menu = ContextualMenu.menu(for: [node])

        // THEN
        let items = try XCTUnwrap(menu?.items)
        XCTAssertEqual(items.count, 9)
        assertMenu(item: items[0], withTitle: UserText.openAllInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: folder)
        assertMenu(item: items[1], withTitle: UserText.openAllTabsInNewWindow, selector: #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)), representedObject: folder)
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.editBookmark, selector: #selector(FolderMenuItemSelectors.editFolder(_:)), representedObject: BookmarkEntityInfo(entity: folder, parent: parent))
        assertMenu(item: items[4], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(FolderMenuItemSelectors.deleteFolder(_:)), representedObject: folder)
        assertMenu(item: items[5], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(FolderMenuItemSelectors.moveToEnd(_:)), representedObject: BookmarkEntityInfo(entity: folder, parent: parent))
        assertMenu(item: items[6], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[7], withTitle: UserText.addFolder, selector: #selector(FolderMenuItemSelectors.newFolder(_:)), representedObject: folder)
        assertMenu(item: items[8], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(FolderMenuItemSelectors.manageBookmarks(_:)))
    }

    func testWhenCreateMenuForMultipleUnfavoriteBookmarksThenReturnsMenuWithOpenInNewTabsAddToFavoritesAndDelete() throws {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: "", title: "", isFavorite: false)
        let bookmark2 = Bookmark(id: "2", url: "", title: "", isFavorite: false)

        // WHEN
        let menu = ContextualMenu.menu(for: [bookmark1, bookmark2])

        // THEN
        let items = try XCTUnwrap(menu?.items)
        XCTAssertEqual(items.count, 4)
        assertMenu(item: items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark1, bookmark2])
        assertMenu(item: items[1], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: [bookmark1, bookmark2])
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark1, bookmark2])
    }

    func testWhenCreateMenuForMultipleFavoriteBookmarksThenReturnsMenuWithOpenInNewTabsRemoveFromFavoritesAndDelete() throws {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: "", title: "", isFavorite: true)
        let bookmark2 = Bookmark(id: "2", url: "", title: "", isFavorite: true)

        // WHEN
        let menu = ContextualMenu.menu(for: [bookmark1, bookmark2])

        // THEN
        let items = try XCTUnwrap(menu?.items)
        XCTAssertEqual(items.count, 4)
        assertMenu(item: items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark1, bookmark2])
        assertMenu(item: items[1], withTitle: UserText.removeFromFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: [bookmark1, bookmark2])
        assertMenu(item: items[2], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[3], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark1, bookmark2])
    }

    func testWhenCreateMenuForMultipleMixedFavoriteBookmarksThenReturnsMenuWithOpenInNewTabsAndDelete() throws {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: "", title: "", isFavorite: true)
        let bookmark2 = Bookmark(id: "2", url: "", title: "", isFavorite: false)

        // WHEN
        let menu = ContextualMenu.menu(for: [bookmark1, bookmark2])

        // THEN
        let items = try XCTUnwrap(menu?.items)
        XCTAssertEqual(items.count, 3)
        assertMenu(item: items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark1, bookmark2])
        assertMenu(item: items[1], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[2], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark1, bookmark2])
    }

    func testWhenCreateMenuForBookmarkAndFolderThenReturnsMenuWithOpenInNewTabsOnlyForBookmarkAndDelete() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: "", title: "Bookmark", isFavorite: true)
        let folder = BookmarkFolder(id: "1", title: "Folder")

        // WHEN
        let menu = ContextualMenu.menu(for: [bookmark, folder])

        // THEN
        let items = try XCTUnwrap(menu?.items)
        XCTAssertEqual(items.count, 3)
        assertMenu(item: items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark])
        assertMenu(item: items[1], withTitle: "", selector: nil) // Separator
        assertMenu(item: items[2], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark, folder])
    }

}

private extension ContextualMenuTests {

    func assertMenu<T: Equatable>(item: NSMenuItem, withTitle title: String, selector: Selector?, representedObject: T = Empty() ) {
        XCTAssertEqual(item.title, title)
        XCTAssertEqual(item.action, selector)
        if representedObject is Empty {
            XCTAssertNil(item.representedObject)
        } else {
            XCTAssertEqualValue(item.representedObject, representedObject)
        }
    }

}

private struct Empty: Equatable {}

private func XCTAssertEqualValue<T>(_ expression1: @autoclosure () throws -> Any?, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) where T: Equatable {
    do {
        guard let firstValue = try expression1() as? T else {
            XCTFail("Type of expression1 \(type(of: try? expression1())) and expression2 \(type(of: try? expression2())) are different.")
            return
        }
        let secondValue = try expression2()
        XCTAssertEqual(firstValue, secondValue, message(), file: file, line: line)
    } catch {
        XCTFail("Failed evaluating expression.")
    }
}
