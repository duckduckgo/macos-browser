//
//  AddEditBookmarkDialogViewModelTests.swift
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

@MainActor
final class AddEditBookmarkDialogViewModelTests: XCTestCase {
    private var bookmarkManager: LocalBookmarkManager!
    private var bookmarkStoreMock: BookmarkStoreMock!

    override func setUpWithError() throws {
        try super.setUpWithError()
        bookmarkStoreMock = BookmarkStoreMock()
        bookmarkStoreMock.bookmarks = [BookmarkFolder.mock]
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
    }

    override func tearDownWithError() throws {
        bookmarkStoreMock = nil
        bookmarkManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Copy

    func testReturnAddBookmarkTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Title.addBookmark)
    }

    func testReturnEditBookmarkTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Title.editBookmark)
    }

    func testReturnCancelActionTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    func testReturnCancelActionTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    func testReturnAddBookmarkActionTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Action.addBookmark)
    }

    func testReturnSaveActionTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.save)
    }

    // MARK: State

    func testShouldSetBookmarkNameToEmptyWhenInitModeIsAddAndTabInfoIsNil() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.bookmarkName

        // THEN
        XCTAssertTrue(result.isEmpty)
    }

    func testWhenInitModeIsAddAndTabInfoIsNotNilAndURLIsNotAlreadyBookmarkedThenSetURLToValue() {
        // GIVEN
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link), title: "Test")
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let url = sut.bookmarkURLPath

        // THEN
        XCTAssertEqual(url, URL.duckDuckGo.absoluteString)
    }

    func testWhenInitAndModeIsAddAndTabInfoTitleIsNotNilAndURLIsNotAlreadyBookmarkedThenSetBookmarkNameToTitle() {
        // GIVEN
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link), title: "Test")
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let name = sut.bookmarkName

        // THEN
        XCTAssertEqual(name, "Test")
    }

    func testWhenInitAndModeIsAddAndTabInfoTitleIsNilAndURLIsNotAlreadyBookmarkedThenSetBookmarkNameToURLDomain() {
        // GIVEN
        let url = URL.duckDuckGo
        let tab = Tab(content: .url(url, source: .link), title: nil)
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let name = sut.bookmarkName

        // THEN
        XCTAssertEqual(name, url.host)
    }

    func testWhenInitAndModeIsAddAndTabInfoTitleIsNilAndURLDoesNotConformToRFC3986AndURLIsNotAlreadyBookmarkedThenSetBookmarkNameToURLAbsoluteString() throws {
        // GIVEN
        let url = try XCTUnwrap(URL(string: "duckduckgo.com"))
        let tab = Tab(content: .url(url, source: .link), title: nil)
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let name = sut.bookmarkName

        // THEN
        XCTAssertEqual(name, url.absoluteString)
    }

    func testShouldSetNameAndURLToEmptyWhenInitModeIsAddTabInfoIsNotNilAndURLIsAlreadyBookmarked() throws {
        // GIVEN
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link), title: "Test")
        let websiteInfo = try XCTUnwrap(WebsiteInfo(tab))
        let bookmark = Bookmark(id: "1", url: websiteInfo.url.absoluteString, title: websiteInfo.title, isFavorite: false)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let name = sut.bookmarkName
        let url = sut.bookmarkURLPath

        // THEN
        XCTAssertEqual(name, "")
        XCTAssertEqual(url, "")
    }

    func testShouldSetBookmarkNameToValueWhenInitAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.bookmarkName

        // THEN
        XCTAssertEqual(result, #function)
    }

    func testShouldSetFoldersFromBookmarkListWhenInitAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folders

        // THEN
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.entity, folder)
    }

    func testShouldSetFoldersFromBookmarkListWhenInitAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folders

        // THEN
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.entity, folder)
    }

    func testShouldSetSelectedFolderToNilWhenBookmarkParentFolderIsNilAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    func testShouldSetSelectedFolderToValueWhenParentFolderIsNotNilAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(parentFolder: folder), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, folder)
    }

    func testShouldSetSelectedFolderToNilWhenParentFolderIsNilAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "2")
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    func testShouldSetSelectedFolderToValueWhenParentFolderIsNotNilAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "1")
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, folder)
    }

    func testShouldSetIsBookmarkFavoriteToTrueWhenModeIsAddAndShouldPresetFavoriteIsTrue() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(shouldPresetFavorite: true), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isBookmarkFavorite

        // THEN
        XCTAssertTrue(result)
    }

    func testShouldNotSetIsBookmarkFavoriteToTrueWhenModeIsAddAndShouldPresetFavoriteIsFalse() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(shouldPresetFavorite: false), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isBookmarkFavorite

        // THEN
        XCTAssertFalse(result)
    }

    // MARK: - Actions

    func testReturnIsCancelActionDisabledFalseWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsCancelActionDisabledFalseWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsDefaultActionButtonDisabledTrueWhenBookmarkNameIsEmptyAndModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        sut.bookmarkName = ""
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    func testReturnIsDefaultActionButtonDisabledTrueWhenBookmarkNameIsEmptyAndModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)
        sut.bookmarkName = ""
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    func testReturnIsDefaultActionButtonDisabledFalseWhenBookmarkNameIsNotEmptyAndModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        sut.bookmarkName = " DuckDuckGo "
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsDefaultActionButtonDisabledFalseWhenBookmarkNameIsNotEmptyAndModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)
        sut.bookmarkName = " DuckDuckGo "
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsDefaultActionButtonDisabledTrueWhenBookmarURLIsEmptyAndModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        sut.bookmarkName = "DuckDuckGo"
        sut.bookmarkURLPath = ""

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    func testReturnIsDefaultActionButtonDisabledTrueWhenBookmarkURLIsEmptyAndModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)
        sut.bookmarkName = "DuckDuckGo"
        sut.bookmarkURLPath = ""

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    func testReturnIsDefaultActionButtonDisabledFalseWhenBookmarkURLIsNotEmptyAndModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        sut.bookmarkName = " DuckDuckGo "
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsDefaultActionButtonDisabledFalseWhenBookmarkURLIsNotEmptyAndModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)
        sut.bookmarkName = " DuckDuckGo "
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testShouldCallDismissWhenCancelIsCalled() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        var didCallDismiss = false

        // WHEN
        sut.cancel {
            didCallDismiss = true
        }

        // THEN
        XCTAssertTrue(didCallDismiss)
    }

    func testShouldCallDismissWhenAddOrSaveIsCalled() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        sut.bookmarkName = "DuckDuckGo"
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString
        var didCallDismiss = false

        // WHEN
        sut.addOrSave {
            didCallDismiss = true
        }

        // THEN
        XCTAssertTrue(didCallDismiss)
    }

    func testShouldAskBookmarkStoreToSaveBookmarkWhenModeIsAddAndURLIsNotAnExistingBookmark() {
        // GIVEN
        let folder = BookmarkFolder(id: #file, title: #function)
        let existingBookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true)
        bookmarkStoreMock.bookmarks = [existingBookmark]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(parentFolder: folder), bookmarkManager: bookmarkManager)
        sut.bookmarkName = "DDG"
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolder)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertTrue(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertTrue(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedObjectUUIDs, [existingBookmark.id])
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .parent(uuid: folder.id))
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark?.title, "DDG")
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark?.url, URL.duckDuckGo.absoluteString)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolder)
    }

    func testShouldAskBookmarkStoreToUpdateBookmarkWhenModeIsAddAndURLIsAnExistingBookmark() {
        // GIVEN
        let folder = BookmarkFolder(id: #file, title: #function)
        let sut = AddEditBookmarkDialogViewModel(mode: .add(parentFolder: folder), bookmarkManager: bookmarkManager)
        sut.bookmarkName = #function
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolder)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertTrue(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark?.title, #function)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark?.url, URL.duckDuckGo.absoluteString)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolder, folder)
    }

    func testShouldAskBookmarkStoreToUpdateBookmarkWhenURLIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.exti, title: #function, isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        sut.bookmarkURLPath = expectedBookmark.url
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertTrue(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark, expectedBookmark)
    }

    func testShouldNotAskBookmarkStoreToUpdateBookmarkWhenURLIsNotUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)
    }

    func testShouldAskBookmarkStoreToUpdateBookmarkWhenNameIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        sut.bookmarkName = expectedBookmark.title
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertTrue(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark, expectedBookmark)
    }

    func testShouldNotAskBookmarkStoreToUpdateBookmarkWhenNameIsNotUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        sut.bookmarkName = #function
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)
    }

    func testShouldAskBookmarkStoreToUpdateBookmarkWhenIsFavoriteIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: true)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        sut.isBookmarkFavorite = expectedBookmark.isFavorite
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertTrue(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark, expectedBookmark)
    }

    func testShouldNotAskBookmarkStoreToUpdateBookmarkWhenIsFavoriteIsNotUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        sut.isBookmarkFavorite = false
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)
    }

    func testShouldAskBookmarkStoreToUpdateBookmarkWhenURLAndTitleAndIsFavoriteIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.exti, title: "DDG", isFavorite: true)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        sut.bookmarkURLPath = expectedBookmark.url
        sut.bookmarkName = expectedBookmark.title
        sut.isBookmarkFavorite = expectedBookmark.isFavorite
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertTrue(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmark, expectedBookmark)
    }

    func testShouldAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsDifferentFromOriginalFolderAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "ABCDE", title: "Test Folder")
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [folder, bookmark]
        bookmarkManager.loadBookmarks()
        sut.selectedFolder = folder
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertTrue(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedObjectUUIDs, [bookmark.id])
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .parent(uuid: folder.id))
    }

    func testShouldAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsNilAndOriginalFolderIsNotRootFolderAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "ABCDE")
        let folder = BookmarkFolder(id: "ABCDE", title: "Test Folder", children: [bookmark])
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [folder, bookmark]
        bookmarkManager.loadBookmarks()
        sut.selectedFolder = nil
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertTrue(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedObjectUUIDs, [bookmark.id])
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .root)
    }

    func testShouldNotAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsNotDifferentFromOriginalFolderAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "ABCDE")
        let folder = BookmarkFolder(id: "ABCDE", title: "Test Folder", children: [bookmark])
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        sut.selectedFolder = folder
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)
    }

    func testShouldNotAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsNilAndOriginalFolderIsRootAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "bookmarks_root")
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        bookmarkStoreMock.bookmarks = [bookmark]
        bookmarkManager.loadBookmarks()
        sut.selectedFolder = nil
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)
    }
}
