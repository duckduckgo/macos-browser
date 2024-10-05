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

final class AddEditBookmarkDialogViewModelTests: XCTestCase {
    private var bookmarkManager: LocalBookmarkManager!
    private var bookmarkStoreMock: BookmarkStoreMock!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [BookmarkFolder.mock])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
    }

    override func tearDownWithError() throws {
        bookmarkStoreMock = nil
        bookmarkManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Copy

    @MainActor
    func testReturnAddBookmarkTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Title.addBookmark)
    }

    @MainActor
    func testReturnEditBookmarkTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Title.editBookmark)
    }

    @MainActor
    func testReturnCancelActionTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    @MainActor
    func testReturnCancelActionTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    @MainActor
    func testReturnAddBookmarkActionTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Action.addBookmark)
    }

    @MainActor
    func testReturnSaveActionTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.save)
    }

    // MARK: State

    @MainActor
    func testShouldSetBookmarkNameToEmptyWhenInitModeIsAddAndTabInfoIsNil() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.bookmarkName

        // THEN
        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func testWhenInitModeIsAddAndTabInfoIsNotNilAndURLIsNotAlreadyBookmarkedThenSetURLToValue() {
        // GIVEN
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link), title: "Test")
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let url = sut.bookmarkURLPath

        // THEN
        XCTAssertEqual(url, URL.duckDuckGo.absoluteString)
    }

    @MainActor
    func testWhenInitAndModeIsAddAndTabInfoTitleIsNotNilAndURLIsNotAlreadyBookmarkedThenSetBookmarkNameToTitle() {
        // GIVEN
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link), title: "Test")
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let name = sut.bookmarkName

        // THEN
        XCTAssertEqual(name, "Test")
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    func testShouldSetNameAndURLToEmptyWhenInitModeIsAddTabInfoIsNotNilAndURLIsAlreadyBookmarked() throws {
        // GIVEN
        let tab = Tab(content: .url(URL.duckDuckGo, source: .link), title: "Test")
        let websiteInfo = try XCTUnwrap(WebsiteInfo(tab))
        let bookmark = Bookmark(id: "1", url: websiteInfo.url.absoluteString, title: websiteInfo.title, isFavorite: false)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(tabWebsite: WebsiteInfo(tab)), bookmarkManager: bookmarkManager)

        // WHEN
        let name = sut.bookmarkName
        let url = sut.bookmarkURLPath

        // THEN
        XCTAssertEqual(name, "")
        XCTAssertEqual(url, "")
    }

    @MainActor
    func testShouldSetBookmarkNameToValueWhenInitAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.bookmarkName

        // THEN
        XCTAssertEqual(result, #function)
    }

    @MainActor
    func testShouldSetFoldersFromBookmarkListWhenInitAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folders

        // THEN
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.entity, folder)
    }

    @MainActor
    func testShouldSetFoldersFromBookmarkListWhenInitAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folders

        // THEN
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.entity, folder)
    }

    @MainActor
    func testShouldSetSelectedFolderToNilWhenBookmarkParentFolderIsNilAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    @MainActor
    func testShouldSetSelectedFolderToValueWhenParentFolderIsNotNilAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .add(parentFolder: folder), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, folder)
    }

    @MainActor
    func testShouldSetSelectedFolderToNilWhenParentFolderIsNilAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "2")
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    @MainActor
    func testShouldSetSelectedFolderToValueWhenParentFolderIsNotNilAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "1")
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, folder)
    }

    @MainActor
    func testShouldSetIsBookmarkFavoriteToTrueWhenModeIsAddAndShouldPresetFavoriteIsTrue() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(shouldPresetFavorite: true), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isBookmarkFavorite

        // THEN
        XCTAssertTrue(result)
    }

    @MainActor
    func testShouldNotSetIsBookmarkFavoriteToTrueWhenModeIsAddAndShouldPresetFavoriteIsFalse() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(shouldPresetFavorite: false), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isBookmarkFavorite

        // THEN
        XCTAssertFalse(result)
    }

    // MARK: - Actions

    @MainActor
    func testReturnIsCancelActionDisabledFalseWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    @MainActor
    func testReturnIsCancelActionDisabledFalseWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
    func testShouldAskBookmarkStoreToSaveBookmarkWhenModeIsAddAndURLIsNotAnExistingBookmark() {
        // GIVEN
        let folder = BookmarkFolder(id: #file, title: #function)
        let existingBookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [existingBookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
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

    @MainActor
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
        XCTAssertNil(bookmarkStoreMock.capturedBookmark)
        let result = bookmarkStoreMock.saveEntitiesAtIndicesCalledWith?.first?.entity as? Bookmark
        XCTAssertEqual(result?.title, #function)
        XCTAssertEqual(result?.url, URL.duckDuckGo.absoluteString)
        XCTAssertEqual(result?.parentFolderUUID, folder.id)
    }

    @MainActor
    func testShouldAskBookmarkStoreToUpdateBookmarkWhenURLIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.exti, title: #function, isFavorite: false)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        sut.bookmarkURLPath = expectedBookmark.url
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

    @MainActor
    func testShouldNotAskBookmarkStoreToUpdateBookmarkWhenURLIsNotUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
        sut.bookmarkURLPath = URL.duckDuckGo.absoluteString
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

    @MainActor
    func testShouldAskBookmarkStoreToUpdateBookmarkWhenNameIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: false)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldNotAskBookmarkStoreToUpdateBookmarkWhenNameIsNotUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldAskBookmarkStoreToUpdateBookmarkWhenIsFavoriteIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: true)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldNotAskBookmarkStoreToUpdateBookmarkWhenIsFavoriteIsNotUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldAskBookmarkStoreToUpdateBookmarkWhenURLAndTitleAndIsFavoriteIsUpdatedAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        let expectedBookmark = Bookmark(id: "1", url: URL.exti, title: "DDG", isFavorite: true)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsDifferentFromOriginalFolderAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "ABCDE", title: "Test Folder")
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder, bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsNilAndOriginalFolderIsNotRootFolderAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "ABCDE")
        let folder = BookmarkFolder(id: "ABCDE", title: "Test Folder", children: [bookmark])
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder, bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldNotAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsNotDifferentFromOriginalFolderAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "ABCDE")
        let folder = BookmarkFolder(id: "ABCDE", title: "Test Folder", children: [bookmark])
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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

    @MainActor
    func testShouldNotAskBookmarkStoreToMoveBookmarkWhenSelectedFolderIsNilAndOriginalFolderIsRootAndModeIsEdit() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: #function, isFavorite: false, parentFolderUUID: "bookmarks_root")
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [bookmark])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkDialogViewModel(mode: .edit(bookmark: bookmark), bookmarkManager: bookmarkManager)
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
