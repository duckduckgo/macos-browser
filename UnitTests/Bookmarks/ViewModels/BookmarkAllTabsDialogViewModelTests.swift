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

final class BookmarkAllTabsDialogViewModelTests: XCTestCase {
    private var bookmarkManager: LocalBookmarkManager!
    private var bookmarkStoreMock: BookmarkStoreMock!
    private var foldersStoreMock: BookmarkFolderStoreMock!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [BookmarkFolder.mock])
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

    @MainActor
    func testWhenTitleIsCalledThenItReflectsThenNumberOfWebsites() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, occurrences: 10)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, String(format: UserText.Bookmarks.Dialog.Title.bookmarkOpenTabs, websitesInfo.count))
    }

    @MainActor
    func testWhenCancelActionTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    @MainActor
    func testWhenEducationalMessageIsCalledThenItReturnsTheRightMessage() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.educationalMessage

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Message.bookmarkOpenTabsEducational)
    }

    @MainActor
    func testWhenDefaultActionTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Action.addAllBookmarks)
    }

    @MainActor
    func testWhenFolderNameFieldTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.folderNameFieldTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Field.folderName)
    }

    @MainActor
    func testWhenLocationFieldTitleIsCalledThenItReturnsTheRightTitle() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.locationFieldTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Field.location)
    }

    // MARK: - State

    @MainActor
    func testWhenInitThenFolderNameIsSetToCurrentDateAndNumberOfWebsites() throws {
        // GIVEN
        let date = Date(timeIntervalSince1970: 1712902304) // 12th of April 2024
        let gmtTimeZone = try XCTUnwrap(TimeZone(identifier: "GMT"))
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, occurrences: 5)
        let sut = BookmarkAllTabsDialogViewModel(
            websites: websitesInfo,
            foldersStore: foldersStoreMock,
            bookmarkManager: bookmarkManager,
            dateFormatterConfigurationProvider: {
                BookmarkAllTabsDialogViewModel.DateFormatterConfiguration(date: date, timeZone: gmtTimeZone)
            }
        )

        // WHEN
        let result = sut.folderName

        // THEN
        XCTAssertEqual(result, String(format: UserText.Bookmarks.Dialog.Value.folderName, "2024-04-12", websitesInfo.count))
    }

    @MainActor
    func testWhenInitAndTimeZoneIsPDTThenFolderNameIsSetToCurrentDateAndNumberOfWebsites() throws {
        // GIVEN
        let date = Date(timeIntervalSince1970: 1712902304) // 12th of April 2024 (GMT)
        let pdtTimeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let expectedDate = "2024-04-11" // Expected date in PDT TimeZone
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, occurrences: 5)
        let sut = BookmarkAllTabsDialogViewModel(
            websites: websitesInfo,
            foldersStore: foldersStoreMock,
            bookmarkManager: bookmarkManager,
            dateFormatterConfigurationProvider: {
                BookmarkAllTabsDialogViewModel.DateFormatterConfiguration(date: date, timeZone: pdtTimeZone)
            }
        )

        // WHEN
        let result = sut.folderName

        // THEN
        XCTAssertEqual(result, String(format: UserText.Bookmarks.Dialog.Value.folderName, expectedDate, websitesInfo.count))
    }

    @MainActor
    func testWhenInitThenFoldersAreSetFromBookmarkList() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folders

        // THEN
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.entity, folder)
    }

    @MainActor
    func testWhenInitAndFoldersStoreLastUsedFolderIsNilThenDoNotAskBookmarkStoreForBookmarkFolder() {
        // GIVEN
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = nil
        XCTAssertFalse(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolderId)

        // WHEN
        _ = BookmarkAllTabsDialogViewModel(websites: WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo), foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // THEN
        XCTAssertFalse(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolderId)
    }

    @MainActor
    func testWhenInitAndFoldersStoreLastUsedFolderIsNotNilThenAskBookmarkStoreForBookmarkFolder() {
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = "1ABCDE"
        XCTAssertFalse(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolderId)

        // WHEN
        _ = BookmarkAllTabsDialogViewModel(websites: WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo), foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // THEN
        XCTAssertTrue(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolderId, "1ABCDE")
    }

    @MainActor
    func testWhenFoldersStoreLastUsedFolderIsNotNilAndBookmarkStoreDoesNotContainFolderThenSelectedFolderIsNil() throws {
        // GIVEN
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = "1"
        bookmarkManager.loadBookmarks()
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    @MainActor
    func testWhenFoldersStoreLastUsedFolderIsNotNilThenSelectedFolderIsNotNil() throws {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        foldersStoreMock.lastBookmarkAllTabsFolderIdUsed = "1"
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, folder)
    }

    @MainActor
    func testWhenFolderIsAddedThenFoldersListIsRefreshed() {
        // GIVEN
        let expectation = self.expectation(description: #function)
        expectation.expectedFulfillmentCount = 2
        let folder = BookmarkFolder(id: "1", title: #function)
        let folder2 = BookmarkFolder(id: "2", title: "Test")
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        bookmarkManager = .init(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        XCTAssertEqual(sut.folders.count, 1)
        XCTAssertEqual(sut.folders.first?.entity, folder)

        // Simulate Bookmark store changing data set
        bookmarkStoreMock.save(entitiesAtIndices: [(folder2, nil, nil)], completion: { _ in })
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

    @MainActor
    func testWhenIsOtherActionDisabledCalledThenReturnFalse() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    @MainActor
    func testWhenFolderNameIsEmptyDefaultActionIsDisabled() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.folderName = ""

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    @MainActor
    func testWhenFolderNameIsNotEmptyDefaultActionIsEnabled() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.folderName = "TEST"

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    @MainActor
    func testWhenCancelIsCalledThenDismissIsCalled() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        var didCallDismiss = false

        // WHEN
        sut.cancel {
            didCallDismiss = true
        }

        // THEN
        XCTAssertTrue(didCallDismiss)
    }

    @MainActor
    func testWhenAddOrSaveIsCalledAndSelectedFolderIsNilThenBookmarkStoreIsAskedToBookmarkWebsitesInfoInRootFolder() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.selectedFolder = nil
        XCTAssertFalse(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertNil(bookmarkStoreMock.capturedWebsitesInfo)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave(dismiss: {})

        // THEN
        XCTAssertTrue(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedWebsitesInfo, websitesInfo)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .root)

    }

    @MainActor
    func testWhenAddOrSaveIsCalledAndSelectedFolderIsNotNilThenBookmarkStoreIsAskedToBookmarkWebsitesInfoNotInRootFolder() {
        // GIVEN
        let folder = BookmarkFolder(id: "ABCDE", title: "Saved Tabs")
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
        let sut = BookmarkAllTabsDialogViewModel(websites: websitesInfo, foldersStore: foldersStoreMock, bookmarkManager: bookmarkManager)
        sut.selectedFolder = folder
        XCTAssertFalse(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertNil(bookmarkStoreMock.capturedWebsitesInfo)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave(dismiss: {})

        // THEN
        XCTAssertTrue(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedWebsitesInfo, websitesInfo)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .parent(uuid: "ABCDE"))
    }

    @MainActor
    func testWhenAddOrSaveIsCalledThenDismissIsCalled() {
        // GIVEN
        let websitesInfo = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo)
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
