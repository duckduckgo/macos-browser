//
//  BookmarkAllTabsDialogViewModelTests.swift
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
final class BookmarkAllTabsDialogViewModelTests: XCTestCase {
    private var bookmarkManager: LocalBookmarkManager!
    private var bookmarkStoreMock: BookmarkStoreMock!
    private var foldersStoreMock: BookmarkFolderStoreMock!

    override func setUpWithError() throws {
        try super.setUpWithError()
        bookmarkStoreMock = BookmarkStoreMock()
        bookmarkStoreMock.bookmarks = [BookmarkFolder.mock]
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        foldersStoreMock = .init()
    }

    override func tearDownWithError() throws {
        bookmarkStoreMock = nil
        bookmarkManager = nil
        foldersStoreMock = nil
        try super.tearDownWithError()
    }

    // MARK: - Copy

    func testWhenTitleIsCalledThenItReflectsThenNumberOfWebsites() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo, occurrences: 10)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, String(format: UserText.Bookmarks.Dialog.Title.bookmarkOpenTabs, websitesInfo.count))
    }

    func testWhenCancelActionTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    func testWhenEducationalMessageIsCalledThenItReturnsTheRightMessage() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.educationalMessage

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Message.bookmarkOpenTabsEducational)
    }

    func testWhenDefaultActionTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Action.addAllBookmarks)
    }

    func testWhenFolderNameFieldTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.folderNameFieldTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Field.folderName)
    }

    func testWhenLocationFieldTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.locationFieldTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Field.location)
    }

    // MARK: - State

    func testWhenInitThenFolderNameIsSetToCurrentDateAndNumberOfWebsites() {
        // GIVEN
        let date = Date(timeIntervalSince1970: 1712902304) // 12th of April 2024
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo, occurrences: 5)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager, dateProvider: { date })

        // WHEN
        let result = sut.folderName

        // THEN
        XCTAssertEqual(result, String(format: UserText.Bookmarks.Dialog.Value.folderName, "2024-04-12", websitesInfo.count))
    }

    func testWhenInitThenFoldersAreSetFromBookmarkList() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folders

        // THEN
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.entity, folder)
    }

    func testWhenInitAndFoldersStoreLastUsedFolderIsNilThenDoNotAskBookmarkStoreForBookmarkFolder() {
        // GIVEN
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = nil
        XCTAssertFalse(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolderId)

        // WHEN
        _ = BookmarkAllTabsDialogViewModel(websites: makeWebsitesInfo(url: .duckDuckGo), foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // THEN
        XCTAssertFalse(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolderId)
    }

    func testWhenInitAndFoldersStoreLastUsedFolderIsNotNilThenAskBookmarkStoreForBookmarkFolder() {
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = "1ABCDE"
        XCTAssertFalse(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolderId)

        // WHEN
        _ = BookmarkAllTabsDialogViewModel(websites: makeWebsitesInfo(url: .duckDuckGo), foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // THEN
        XCTAssertTrue(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolderId, "1ABCDE")
    }

    func testWhenFoldersStoreLastUsedFolderIsNotNilAndBookmarkStoreDoesNotContainFolderThenSelectedFolderIsNil() throws {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = "1"
        bookmarkStoreMock.bookmarkFolder = nil
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    func testWhenFoldersStoreLastUsedFolderIsNotNilThenSelectedFolderIsNotNil() throws {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = "1"
        bookmarkStoreMock.bookmarkFolder = folder
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, folder)
    }

    func testWhenFolderIsAddedThenFoldersListIsRefreshed() {
        // GIVEN
        let expectation = self.expectation(description: #function)
        expectation.expectedFulfillmentCount = 2
        let folder = BookmarkFolder(id: "1", title: #function)
        let folder2 = BookmarkFolder(id: "2", title: "Test")
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        XCTAssertEqual(sut.folders.count, 1)
        XCTAssertEqual(sut.folders.first?.entity, folder)

        // Simulate Bookmark store changing data set
        bookmarkStoreMock.bookmarks = [folder, folder2]
        var expectedFolder: [BookmarkFolder] = []
        let c = sut.$folders
            .dropFirst()
            .sink { folders in
            expectedFolder = folders.map(\.entity)
            expectation.fulfill()
        }

        // WHEN
        bookmarkManager.loadBookmarks()

        // THEN
        withExtendedLifetime(c) {}
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(expectedFolder.count, 2)
        XCTAssertEqual(expectedFolder.first, folder)
        XCTAssertEqual(expectedFolder.last, folder2)
    }

    // MARK: - Actions

    func testWhenIsOtherActionDisabledCalledThenReturnFalse() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testWhenFolderNameIsEmptyDefaultActionIsDisabled() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.folderName = ""

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    func testWhenFolderNameIsNotEmptyDefaultActionIsEnabled() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.folderName = "TEST"

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testWhenCancelIsCalledThenDismissIsCalled() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        var didCallDismiss = false

        // WHEN
        sut.cancel {
            didCallDismiss = true
        }

        // THEN
        XCTAssertTrue(didCallDismiss)
    }

    func testWhenAddOrSaveIsCalledAndSelectedFolderIsNilThenBookmarkStoreIsAskedToBookmarkWebsitesInfoInRootFolder() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.selectedFolder = nil
        XCTAssertFalse(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmarks)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave(dismiss: {})

        // THEN
        XCTAssertTrue(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmarks?.compactMap(\.urlObject), websitesInfo.map(\.url))
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .root)

    }

    func testWhenAddOrSaveIsCalledAndSelectedFolderIsNotNilThenBookmarkStoreIsAskedToBookmarkWebsitesInfoNotInRootFolder() {
        // GIVEN
        let folder = BookmarkFolder(id: "ABCDE", title: "Saved Tabs")
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.selectedFolder = folder
        XCTAssertFalse(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertNil(bookmarkStoreMock.capturedBookmarks)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave(dismiss: {})

        // THEN
        XCTAssertTrue(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedBookmarks?.compactMap(\.urlObject), websitesInfo.map(\.url))
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .parent(uuid: "ABCDE"))
    }

    func testWhenAddOrSaveIsCalledThenDismissIsCalled() {
        // GIVEN
        let websitesInfo = makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        var didCallDismiss = false

        // WHEN
        sut.addOrSave {
            didCallDismiss = true
        }

        // THEN
        XCTAssertTrue(didCallDismiss)
    }

}

// MARK: - Private

private extension BookmarkAllTabsDialogViewModelTests {

    func makeWebsitesInfo(url: URL, occurrences: Int = 1) -> [WebsiteInfo] {
        (1...occurrences)
            .map { _ in
                Tab(content: .url(url, credential: nil, source: .ui))
            }
            .compactMap(WebsiteInfo.init)
    }
}
