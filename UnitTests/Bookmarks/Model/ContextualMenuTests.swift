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

    override func tearDown() {
        NSPasteboard.swizzledGeneralPasteboardValue = nil
    }

    // MARK: - Tests

    @MainActor
    func testWhenAskingBookmarkMenuItemsAndIsNotFavoriteThenItShouldReturnTheItemsInTheCorrectOrder() {
        // GIVEN
        let isFavorite = false
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: isFavorite, parentFolderUUID: "1")

        // WHEN
        let items = BookmarksContextMenu.bookmarkMenuItems(with: bookmark)

        // THEN
        XCTAssertEqual(items.count, 12)
        assertMenuItem(items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
        assertMenuItem(items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
        XCTAssertTrue(items[4].isSeparatorItem) // Separator
        assertMenuItem(items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: bookmark)
        XCTAssertTrue(items[9].isSeparatorItem) // Separator
        assertMenuItem(items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)), representedObject: bookmark)
        assertMenuItem(items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    @MainActor
    func testWhenAskingBookmarkMenuItemsAndIsFavoriteThenItShouldReturnTheItemsInTheCorrectOrder() {
        // GIVEN
        let isFavorite = true
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: isFavorite, parentFolderUUID: "1")

        // WHEN
        let items = BookmarksContextMenu.bookmarkMenuItems(with: bookmark)

        // THEN
        assertMenuItem(items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
        assertMenuItem(items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.removeFromFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
        XCTAssertTrue(items[4].isSeparatorItem) // Separator
        assertMenuItem(items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: bookmark)
        XCTAssertTrue(items[9].isSeparatorItem) // Separator
        assertMenuItem(items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)), representedObject: bookmark)
        assertMenuItem(items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    @MainActor
    func testWhenAskingBookmarkMenuItemsWithoutManageBookmarks_manageBookmarksItemIsMissing() {
        // GIVEN
        let isFavorite = true
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: isFavorite, parentFolderUUID: "1")

        // WHEN
        let items = BookmarksContextMenu.bookmarkMenuItems(with: bookmark, enableManageBookmarks: false)

        // THEN
        assertMenuItem(items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
        assertMenuItem(items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.removeFromFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
        XCTAssertTrue(items[4].isSeparatorItem) // Separator
        assertMenuItem(items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: bookmark)
        XCTAssertTrue(items[9].isSeparatorItem) // Separator
        assertMenuItem(items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)), representedObject: bookmark)
    }

    @MainActor
    func testWhenAskingFolderItemThenItShouldReturnTheItemsInTheCorrectOrders() {
        // WHEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false)
        let folder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [bookmark])
        let items = BookmarksContextMenu.folderMenuItems(with: folder)

        // THEN
        XCTAssertEqual(items.count, 9)
        assertMenuItem(items[0], withTitle: UserText.openAllInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: folder)
        assertMenuItem(items[1], withTitle: UserText.openAllTabsInNewWindow, selector: #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)), representedObject: folder)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.editBookmark, selector: #selector(FolderMenuItemSelectors.editFolder(_:)), representedObject: folder)
        assertMenuItem(items[4], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(FolderMenuItemSelectors.deleteFolder(_:)), representedObject: folder)
        assertMenuItem(items[5], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(FolderMenuItemSelectors.moveToEnd(_:)), representedObject: folder)
        XCTAssertTrue(items[6].isSeparatorItem) // Separator
        assertMenuItem(items[7], withTitle: UserText.addFolder, selector: #selector(FolderMenuItemSelectors.newFolder(_:)), representedObject: folder)
        assertMenuItem(items[8], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(FolderMenuItemSelectors.manageBookmarks(_:)))
    }

    @MainActor
    func testWhenAskingEmptyFolderItem_OpenAllItemsShouldBeDisabled() {
        // WHEN
        let folder = BookmarkFolder(id: "1", title: "DuckDuckGo", children: [])
        let items = BookmarksContextMenu.folderMenuItems(with: folder)

        // THEN
        XCTAssertEqual(items.count, 9)
        assertMenuItem(items[0], withTitle: UserText.openAllInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: folder, disabled: true)
        assertMenuItem(items[1], withTitle: UserText.openAllTabsInNewWindow, selector: #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)), representedObject: folder, disabled: true)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.editBookmark, selector: #selector(FolderMenuItemSelectors.editFolder(_:)), representedObject: folder)
        assertMenuItem(items[4], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(FolderMenuItemSelectors.deleteFolder(_:)), representedObject: folder)
        assertMenuItem(items[5], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(FolderMenuItemSelectors.moveToEnd(_:)), representedObject: folder)
        XCTAssertTrue(items[6].isSeparatorItem) // Separator
        assertMenuItem(items[7], withTitle: UserText.addFolder, selector: #selector(FolderMenuItemSelectors.newFolder(_:)), representedObject: folder)
        assertMenuItem(items[8], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(FolderMenuItemSelectors.manageBookmarks(_:)))
    }

    @MainActor
    func testWhenCreateMenuForEmptySelectionThenItReturnsAMenuWithAddFolderOnly() throws {
        // WHEN
        let menu = BookmarksContextMenu.menu(for: [])

        // THEN
        XCTAssertEqual(menu.items.count, 1)
        let menuItem = try XCTUnwrap(menu.items.first)
        assertMenuItem(menuItem, withTitle: UserText.addFolder, selector: #selector(FolderMenuItemSelectors.newFolder(_:)))
    }

    @MainActor
    func testWhenCreateMenuForBookmarkWithoutParentThenReturnsAMenuWithTheBookmarkMenuItems() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false)

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [bookmark])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 12)
        assertMenuItem(items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
        assertMenuItem(items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
        XCTAssertTrue(items[4].isSeparatorItem) // Separator
        assertMenuItem(items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: bookmark)
        XCTAssertTrue(items[9].isSeparatorItem) // Separator
        assertMenuItem(items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)), representedObject: bookmark)
        assertMenuItem(items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    @MainActor
    func testWhenCreateMenuForBookmarkWithParentThenReturnsAMenuWithTheBookmarkMenuItems() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false, parentFolderUUID: "A")
        let parent = BookmarkFolder(id: "A", title: "Folder", children: [bookmark])
        let parentNode = BookmarkNode(representedObject: parent, parent: nil)
        let node = BookmarkNode(representedObject: bookmark, parent: parentNode)

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [node])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 12)
        assertMenuItem(items[0], withTitle: UserText.openInNewTab, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewTab(_:)), representedObject: bookmark)
        assertMenuItem(items[1], withTitle: UserText.openInNewWindow, selector: #selector(BookmarkMenuItemSelectors.openBookmarkInNewWindow(_:)), representedObject: bookmark)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: bookmark)
        XCTAssertTrue(items[4].isSeparatorItem) // Separator
        assertMenuItem(items[5], withTitle: UserText.editBookmark, selector: #selector(BookmarkMenuItemSelectors.editBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[6], withTitle: UserText.bookmarksBarContextMenuCopy, selector: #selector(BookmarkMenuItemSelectors.copyBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[7], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteBookmark(_:)), representedObject: bookmark)
        assertMenuItem(items[8], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(BookmarkMenuItemSelectors.moveToEnd(_:)), representedObject: bookmark)
        XCTAssertTrue(items[9].isSeparatorItem) // Separator
        assertMenuItem(items[10], withTitle: UserText.addFolder, selector: #selector(BookmarkMenuItemSelectors.newFolder(_:)), representedObject: bookmark)
        assertMenuItem(items[11], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(BookmarkMenuItemSelectors.manageBookmarks(_:)))
    }

    @MainActor
    func testWhenCreateMenuForFolderNodeThenReturnsAMenuWithTheFolderMenuItems() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false)
        let folder = BookmarkFolder(id: "1", title: "Child", children: [bookmark])
        let parent = BookmarkFolder(id: "1", title: "Parent", children: [folder])
        let parentNode = BookmarkNode(representedObject: parent, parent: nil)
        let node = BookmarkNode(representedObject: folder, parent: parentNode)

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [node])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 9)
        assertMenuItem(items[0], withTitle: UserText.openAllInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: folder)
        assertMenuItem(items[1], withTitle: UserText.openAllTabsInNewWindow, selector: #selector(FolderMenuItemSelectors.openAllInNewWindow(_:)), representedObject: folder)
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.editBookmark, selector: #selector(FolderMenuItemSelectors.editFolder(_:)), representedObject: folder)
        assertMenuItem(items[4], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(FolderMenuItemSelectors.deleteFolder(_:)), representedObject: folder)
        assertMenuItem(items[5], withTitle: UserText.bookmarksBarContextMenuMoveToEnd, selector: #selector(FolderMenuItemSelectors.moveToEnd(_:)), representedObject: folder)
        XCTAssertTrue(items[6].isSeparatorItem) // Separator
        assertMenuItem(items[7], withTitle: UserText.addFolder, selector: #selector(FolderMenuItemSelectors.newFolder(_:)), representedObject: folder)
        assertMenuItem(items[8], withTitle: UserText.bookmarksManageBookmarks, selector: #selector(FolderMenuItemSelectors.manageBookmarks(_:)))
    }

    @MainActor
    func testWhenCreateMenuForMultipleUnfavoriteBookmarksThenReturnsMenuWithOpenInNewTabsAddToFavoritesAndDelete() throws {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: "", title: "", isFavorite: false)
        let bookmark2 = Bookmark(id: "2", url: "", title: "", isFavorite: false)

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [bookmark1, bookmark2])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 4)
        assertMenuItem(items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark1, bookmark2])
        assertMenuItem(items[1], withTitle: UserText.addToFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: [bookmark1, bookmark2])
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark1, bookmark2])
    }

    @MainActor
    func testWhenCreateMenuForMultipleFavoriteBookmarksThenReturnsMenuWithOpenInNewTabsRemoveFromFavoritesAndDelete() throws {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: "", title: "", isFavorite: true)
        let bookmark2 = Bookmark(id: "2", url: "", title: "", isFavorite: true)

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [bookmark1, bookmark2])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 4)
        assertMenuItem(items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark1, bookmark2])
        assertMenuItem(items[1], withTitle: UserText.removeFromFavorites, selector: #selector(BookmarkMenuItemSelectors.toggleBookmarkAsFavorite(_:)), representedObject: [bookmark1, bookmark2])
        XCTAssertTrue(items[2].isSeparatorItem) // Separator
        assertMenuItem(items[3], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark1, bookmark2])
    }

    @MainActor
    func testWhenCreateMenuForMultipleMixedFavoriteBookmarksThenReturnsMenuWithOpenInNewTabsAndDelete() throws {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: "", title: "", isFavorite: true)
        let bookmark2 = Bookmark(id: "2", url: "", title: "", isFavorite: false)

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [bookmark1, bookmark2])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 3)
        assertMenuItem(items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark1, bookmark2])
        XCTAssertTrue(items[1].isSeparatorItem) // Separator
        assertMenuItem(items[2], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark1, bookmark2])
    }

    @MainActor
    func testWhenCreateMenuForBookmarkAndFolderThenReturnsMenuWithOpenInNewTabsOnlyForBookmarkAndDelete() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: "", title: "Bookmark", isFavorite: true)
        let folder = BookmarkFolder(id: "1", title: "Folder")

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [bookmark, folder])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 3)
        assertMenuItem(items[0], withTitle: UserText.bookmarksOpenInNewTabs, selector: #selector(FolderMenuItemSelectors.openInNewTabs(_:)), representedObject: [bookmark])
        XCTAssertTrue(items[1].isSeparatorItem) // Separator
        assertMenuItem(items[2], withTitle: UserText.bookmarksBarContextMenuDelete, selector: #selector(BookmarkMenuItemSelectors.deleteEntities(_:)), representedObject: [bookmark, folder])
    }

    @MainActor
    func testWhenSearchIsHappeningThenMenuForBookmarksReturnsShowInFolder() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false)

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [bookmark], forSearch: true)

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 13)
        assertMenuItem(items[5], withTitle: UserText.showInFolder, selector: #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)), representedObject: bookmark)
    }

    @MainActor
    func testWhenSearchIsHappeningThenMenuForFoldersReturnsShowInFolder() throws {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: "Folder")

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [folder], forSearch: true)

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 10)
        assertMenuItem(items[3], withTitle: UserText.showInFolder, selector: #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)), representedObject: folder)
    }

    @MainActor
    func testWhenGettingContextalMenuForMoreThanOneBookmarkThenShowInFolderIsNotReturned() throws {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: "", title: "Bookmark", isFavorite: true)
        let folder = BookmarkFolder(id: "1", title: "Folder")

        // WHEN
        let menu = BookmarksContextMenu.menu(for: [bookmark, folder])

        // THEN
        let items = try XCTUnwrap(menu.items)
        XCTAssertEqual(items.count, 3)

        for menuItem in items {
            XCTAssertNotEqual(menuItem.title, UserText.showInFolder)
            XCTAssertNotEqual(menuItem.action, #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)))
        }
    }

    @MainActor
    func testWhenGettingContextualMenuForItemThenShowInFolderIsNotReturned() throws {
        // WHEN
        let menu = BookmarksContextMenu.menu(for: [])

        // THEN
        XCTAssertEqual(menu.items.count, 1)
        let menuItem = try XCTUnwrap(menu.items.first)
        XCTAssertNotEqual(menuItem.title, UserText.showInFolder)
        XCTAssertNotEqual(menuItem.action, #selector(BookmarkSearchMenuItemSelectors.showInFolder(_:)))
    }

    // MARK: - Actions

    @MainActor
    func testWhenItemFiresOpenInNewTabAction_showTabCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.openInNewTab }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.windowControllersManager as! WindowControllersManagerMock).showCalled, .init(url: URL.duckDuckGo, source: .bookmark, newTab: true))
    }

    @MainActor
    func testWhenItemFiresOpenInNewWindowAction_openNewWindowCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.openInNewWindow }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.windowControllersManager as! WindowControllersManagerMock).openNewWindowCalled, .init(contents: [TabContent.url(.duckDuckGo, source: .bookmark)], burnerMode: .regular))
    }

    @MainActor
    func testWhenItemFiresOpenAllInNewTabsAction_openNewWindowCalled() {
        // GIVEN
        let bookmark1 = Bookmark(id: "b1", url: "https://test1.com", title: "Test 1", isFavorite: false, parentFolderUUID: "1")
        let bookmark2 = Bookmark(id: "b2", url: "https://test2.com", title: "Test 2", isFavorite: false, parentFolderUUID: "1")
        let bookmark3 = Bookmark(id: "b3", url: "https://test3.com", title: "Test 3", isFavorite: false, parentFolderUUID: "1")
        let folder = BookmarkFolder(id: "1", title: "Folder", children: [bookmark1, bookmark2, bookmark3])
        let menu = BookmarksContextMenu.menu(for: [folder])
        guard let menuItem = menu.items.first(where: { $0.title == UserText.openAllInNewTabs }) else {
            XCTFail("No item")
            return
        }
        let mainViewController = MainViewController(tabCollectionViewModel: TabCollectionViewModel(tabCollection: TabCollection(tabs: [])), autofillPopoverPresenter: DefaultAutofillPopoverPresenter())
        (menu.windowControllersManager as! WindowControllersManagerMock).lastKeyMainWindowController = MainWindowController(mainViewController: mainViewController, popUp: false)

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual(mainViewController.tabCollectionViewModel.tabs.map(\.content), [
            .newtab,
            TabContent.url(bookmark1.urlObject!, source: .bookmark),
            TabContent.url(bookmark2.urlObject!, source: .bookmark),
            TabContent.url(bookmark3.urlObject!, source: .bookmark),
        ])
    }

    @MainActor
    func testWhenItemFiresOpenAllInNewWindowsAction_openNewWindowCalled() {
        // GIVEN
        let bookmark1 = Bookmark(id: "b1", url: "https://test1.com", title: "Test 1", isFavorite: false, parentFolderUUID: "1")
        let bookmark2 = Bookmark(id: "b2", url: "https://test2.com", title: "Test 2", isFavorite: false, parentFolderUUID: "1")
        let bookmark3 = Bookmark(id: "b3", url: "https://test3.com", title: "Test 3", isFavorite: false, parentFolderUUID: "1")
        let folder = BookmarkFolder(id: "1", title: "Folder", children: [bookmark1, bookmark2, bookmark3])
        let menu = BookmarksContextMenu.menu(for: [folder])
        guard let menuItem = menu.items.first(where: { $0.title == UserText.openAllTabsInNewWindow }) else {
            XCTFail("No item")
            return
        }
        let mainViewController = MainViewController(tabCollectionViewModel: TabCollectionViewModel(tabCollection: TabCollection(tabs: [])), autofillPopoverPresenter: DefaultAutofillPopoverPresenter())
        (menu.windowControllersManager as! WindowControllersManagerMock).lastKeyMainWindowController = MainWindowController(mainViewController: mainViewController, popUp: false)

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.windowControllersManager as! WindowControllersManagerMock).openNewWindowCalled, .init(contents: [
            TabContent.url(bookmark1.urlObject!, source: .bookmark),
            TabContent.url(bookmark2.urlObject!, source: .bookmark),
            TabContent.url(bookmark3.urlObject!, source: .bookmark),
        ], burnerMode: .regular))
    }

    @MainActor
    func testWhenItemFiresToggleFavoritesAction_updateBookmarkCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.removeFromFavorites }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.bookmarkManager as! MockBookmarkManager).updateBookmarkCalled, bookmark)
        XCTAssertFalse(bookmark.isFavorite)
    }

    @MainActor
    func testWhenItemFiresEditAction_editDialogShown() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.editBookmark }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertTrue((menu.delegate as! MockBookmarksContextMenuDelegate).showDialogCalledWithView is AddEditBookmarkDialogView)
    }

    @MainActor
    func testWhenItemInRootFiresMoveToEndAction_moveObjectsCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: nil)
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.bookmarksBarContextMenuMoveToEnd }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.bookmarkManager as! MockBookmarkManager).moveObjectsCalled, .init(objectUUIDs: ["n"], toIndex: nil, withinParentFolder: .root))
    }

    @MainActor
    func testWhenItemFiresMoveToEndAction_moveObjectsCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.bookmarksBarContextMenuMoveToEnd }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.bookmarkManager as! MockBookmarkManager).moveObjectsCalled, .init(objectUUIDs: ["n"], toIndex: nil, withinParentFolder: .parent(uuid: "1")))
    }

    @MainActor
    func testWhenItemFiresCopyBookmarkURLAction_itemWrittenToPasteboard() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.copy }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        let pasteboard = NSPasteboard.withUniqueName()
        NSPasteboard.swizzledGeneralPasteboardValue = pasteboard
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)
        XCTAssertEqual(pasteboard.pasteboardItems?.first.map { Set($0.types).intersection([.URL, .string]) }, [.URL, .string])
        XCTAssertEqual(pasteboard.pasteboardItems?.first?.string(forType: .string), URL.duckDuckGo.absoluteString)
        XCTAssertEqual(pasteboard.pasteboardItems?.first?.string(forType: .URL), URL.duckDuckGo.absoluteString)
    }

    @MainActor
    func testWhenItemFiresDeleteBookmarkAction_removeBookmarkCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.bookmarksBarContextMenuDelete }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertTrue((menu.bookmarkManager as! MockBookmarkManager).removeBookmarkCalled)
    }

    @MainActor
    func testWhenItemFiresDeleteFolderAction_removeBookmarkCalled() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: "Folder")
        let menu = BookmarksContextMenu.folderMenu(with: folder)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.bookmarksBarContextMenuDelete }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertTrue((menu.bookmarkManager as! MockBookmarkManager).removeFolderCalled)
    }

    @MainActor
    func testWhenItemFiresDeleteEntitiesAction_removeBookmarkCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let folder = BookmarkFolder(id: "1", title: "Folder")
        let menu = BookmarksContextMenu.menu(for: [bookmark, folder])
        guard let menuItem = menu.items.first(where: { $0.title == UserText.bookmarksBarContextMenuDelete }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.bookmarkManager as! MockBookmarkManager).removeObjectsCalled, ["n", "1"])
    }

    @MainActor
    func testWhenItemFiresAddFolderAction_addFolderDialogShown() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.addFolder }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertTrue((menu.delegate as! MockBookmarksContextMenuDelegate).showDialogCalledWithView is AddEditBookmarkFolderDialogView)
    }

    @MainActor
    func testWhenItemFiresEditFolderAction_addFolderDialogShown() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: "Folder")
        let menu = BookmarksContextMenu.folderMenu(with: folder)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.editBookmark }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertTrue((menu.delegate as! MockBookmarksContextMenuDelegate).showDialogCalledWithView is AddEditBookmarkFolderDialogView)
    }

    @MainActor
    func testWhenItemFiresManageBookmarksAction_showBookmarksCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.bookmarkMenu(with: bookmark)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.bookmarksManageBookmarks }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertTrue((menu.windowControllersManager as! WindowControllersManagerMock).showBookmarksTabCalled)
    }

    @MainActor
    func testWhenBookmarkItemFiresShowInFolderAction_showInFolderDelegateMethodCalled() {
        // GIVEN
        let bookmark = Bookmark(id: "n", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "1")
        let menu = BookmarksContextMenu.menu(for: [bookmark], forSearch: true)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.showInFolder }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.delegate as! MockBookmarksContextMenuDelegate).showInFolderCalledWithObject as? Bookmark, bookmark)
    }

    @MainActor
    func testWhenFolderItemFiresShowInFolderAction_showInFolderDelegateMethodCalled() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: "Folder")
        let menu = BookmarksContextMenu.menu(for: [folder], forSearch: true)
        guard let menuItem = menu.items.first(where: { $0.title == UserText.showInFolder }) else {
            XCTFail("No item")
            return
        }

        // WHEN
        _=menuItem.target!.perform(menuItem.action!, with: menuItem)

        // THEN
        XCTAssertEqual((menu.delegate as! MockBookmarksContextMenuDelegate).showInFolderCalledWithObject as? BookmarkFolder, folder)
    }

}

private extension ContextualMenuTests {

    func assertMenuItem<T: Equatable>(_ item: NSMenuItem, withTitle title: String, selector: Selector?, representedObject: T = Empty(), disabled: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(item.title, title, file: file, line: line)
        XCTAssertEqual(item.action, selector, file: file, line: line)
        if representedObject is Empty {
            XCTAssertNil(item.representedObject, file: file, line: line)
        } else {
            XCTAssertEqualValue(item.representedObject, representedObject, file: file, line: line)
        }
        if disabled {
            XCTAssertFalse(item.isEnabled, file: file, line: line)
        } else {
            XCTAssertTrue(item.isEnabled, file: file, line: line)
        }
    }

}

class MockBookmarksContextMenuDelegate: NSObject, BookmarksContextMenuDelegate {

    var isSearching: Bool = false
    var parentFolder: DuckDuckGo_Privacy_Browser.BookmarkFolder?
    var shouldIncludeManageBookmarksItem: Bool = true
    var undoManager: UndoManager?

    var selectedBookmarkItems: [Any] = []
    func selectedItems() -> [Any] {
        selectedBookmarkItems
    }

    var showDialogCalledWithView: (any DuckDuckGo_Privacy_Browser.ModalView)?
    func showDialog(_ dialog: any DuckDuckGo_Privacy_Browser.ModalView) {
        showDialogCalledWithView = dialog
    }

    var closePopoverCalled = false
    func closePopoverIfNeeded() {
        closePopoverCalled = true
    }

    var showInFolderCalledWithObject: Any?
    func showInFolder(_ sender: NSMenuItem) {
        showInFolderCalledWithObject = sender.representedObject
    }

}

extension BookmarksContextMenu {

    @MainActor
    static func bookmarkMenuItems(with bookmark: Bookmark, enableManageBookmarks: Bool = true) -> [NSMenuItem] {
        bookmarkMenu(with: bookmark, enableManageBookmarks: enableManageBookmarks).items
    }
    @MainActor
    static func bookmarkMenu(with bookmark: Bookmark, enableManageBookmarks: Bool = true) -> BookmarksContextMenu {
        let delegate = MockBookmarksContextMenuDelegate()
        delegate.selectedBookmarkItems = [bookmark]
        delegate.shouldIncludeManageBookmarksItem = enableManageBookmarks
        let bkman = MockBookmarkManager(list: .init(entities: [bookmark], topLevelEntities: [BookmarkFolder(id: PseudoFolder.bookmarks.id, title: "Bookmarks", children: [bookmark])]))
        let menu = BookmarksContextMenu(bookmarkManager: bkman, windowControllersManager: WindowControllersManagerMock(), delegate: delegate)
        menu.onDeinit {
            withExtendedLifetime(delegate) {}
        }
        menu.update()

        return menu
    }
    @MainActor
    static func folderMenuItems(with bookmarkFolder: BookmarkFolder, enableManageBookmarks: Bool = true) -> [NSMenuItem] {
        folderMenu(with: bookmarkFolder, enableManageBookmarks: enableManageBookmarks).items
    }
    @MainActor
    static func folderMenu(with bookmarkFolder: BookmarkFolder, enableManageBookmarks: Bool = true) -> BookmarksContextMenu {
        let delegate = MockBookmarksContextMenuDelegate()
        delegate.selectedBookmarkItems = [bookmarkFolder]
        delegate.shouldIncludeManageBookmarksItem = enableManageBookmarks
        let bkman = MockBookmarkManager(list: .init(entities: [bookmarkFolder], topLevelEntities: [BookmarkFolder(id: PseudoFolder.bookmarks.id, title: "Bookmarks", children: [bookmarkFolder])]))
        let menu = BookmarksContextMenu(bookmarkManager: bkman, windowControllersManager: WindowControllersManagerMock(), delegate: delegate)
        menu.onDeinit {
            withExtendedLifetime(delegate) {}
        }
        menu.update()

        return menu
    }
    @MainActor
    static func menu(for items: [Any], forSearch: Bool = false) -> BookmarksContextMenu {
        let delegate = MockBookmarksContextMenuDelegate()
        delegate.selectedBookmarkItems = items
        delegate.isSearching = forSearch
        let entities = items as? [BaseBookmarkEntity] ?? (items as? [BookmarkNode])!.map { $0.representedObject as! BaseBookmarkEntity }
        let bkman = MockBookmarkManager(list: .init(entities: entities, topLevelEntities: [BookmarkFolder(id: PseudoFolder.bookmarks.id, title: "Bookmarks", children: entities)]))
        let menu = BookmarksContextMenu(bookmarkManager: bkman, windowControllersManager: WindowControllersManagerMock(), delegate: delegate)
        menu.onDeinit {
            withExtendedLifetime(delegate) {}
        }
        menu.update()

        return menu
    }
}

private struct Empty: Equatable {}

private func XCTAssertEqualValue<T>(_ expression1: @autoclosure () throws -> Any?, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) where T: Equatable {
    do {
        guard let firstValue = try expression1() as? T else {
            XCTFail("Type of expression1 \(type(of: try? expression1())) and expression2 \(type(of: try? expression2())) are different.", file: file, line: line)
            return
        }
        let secondValue = try expression2()
        XCTAssertEqual(firstValue, secondValue, message(), file: file, line: line)
    } catch {
        XCTFail("Failed evaluating expression.", file: file, line: line)
    }
}

private extension NSPasteboard {

    private static let originalGeneral = {
        class_getClassMethod(NSPasteboard.self, #selector(getter: general))!
    }()
    private static let swizzledGeneral = {
        class_getClassMethod(NSPasteboard.self, #selector(swizzledGeneralPasteboard))!
    }()

    private static var swizzleGeneralPasteboardOnce: () = {
        dispatchPrecondition(condition: .onQueue(.main))
        method_exchangeImplementations(originalGeneral, swizzledGeneral)
    }()

    static var swizzledGeneralPasteboardValue: NSPasteboard? {
        didSet {
            _=swizzleGeneralPasteboardOnce
        }
    }

    @objc private dynamic class func swizzledGeneralPasteboard() -> NSPasteboard {
        if let swizzledGeneralPasteboardValue {
            return swizzledGeneralPasteboardValue
        }
        return self.swizzledGeneralPasteboard() // call the original
    }

}
