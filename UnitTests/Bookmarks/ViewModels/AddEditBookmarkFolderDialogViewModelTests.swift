//
//  AddEditBookmarkFolderDialogViewModelTests.swift
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
final class AddEditBookmarkFolderDialogViewModelTests: XCTestCase {
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

    func testReturnAddBookmarkFolderTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Title.addFolder)
    }

    func testReturnEditBookmarkFolderTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.title

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Title.editFolder)
    }

    func testReturnCancelActionTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    func testReturnCancelActionTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.cancelActionTitle

        // THEN
        XCTAssertEqual(title, UserText.cancel)
    }

    func testReturnAddBookmarkFolderActionTitleWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.Bookmarks.Dialog.Action.addFolder)
    }

    func testReturnSaveActionTitleWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)

        // WHEN
        let title = sut.defaultActionTitle

        // THEN
        XCTAssertEqual(title, UserText.save)
    }

    // MARK: State

    func testShouldSetFolderNameToEmptyWhenInitAndModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folderName

        // THEN
        XCTAssertTrue(result.isEmpty)
    }

    func testShouldSetFolderNameToValueWhenInitAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folderName

        // THEN
        XCTAssertEqual(result, #function)
    }

    func testShouldSetFoldersFromBookmarkListWhenInitAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        bookmarkManager.loadBookmarks()
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

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
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.folders

        // THEN
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.entity, folder)
    }

    func testShouldSetSelectedFolderToNilWhenParentFolderIsNilAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    func testShouldSetSelectedFolderToValueWhenParentFolderIsNotNilAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, .mock)
    }

    func testShouldSetSelectedFolderToNilWhenParentFolderIsNilAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: nil), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertNil(result)
    }

    func testShouldSetSelectedFolderToValueWhenParentFolderIsNotNilAndModeIsEdit() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: #function)
        bookmarkStoreMock.bookmarks = [folder]
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: .mock), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.selectedFolder

        // THEN
        XCTAssertEqual(result, .mock)
    }

    // MARK: - Actions

    func testReturnIsCancelActionDisabledFalseWhenModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsCancelActionDisabledFalseWhenModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)

        // WHEN
        let result = sut.isOtherActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsDefaultActionButtonDisabledTrueWhenFolderNameIsEmptyAndModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        sut.folderName = ""

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    func testReturnIsDefaultActionButtonDisabledTrueWhenFolderNameIsEmptyAndModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)
        sut.folderName = ""

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertTrue(result)
    }

    func testReturnIsDefaultActionButtonDisabledFalseWhenFolderNameIsNotEmptyAndModeIsAdd() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        sut.folderName = " Test "

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testReturnIsDefaultActionButtonDisabledFalseWhenFolderNameIsNotEmptyAndModeIsEdit() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)
        sut.folderName = " Test "

        // WHEN
        let result = sut.isDefaultActionDisabled

        // THEN
        XCTAssertFalse(result)
    }

    func testShouldCallDismissWhenCancelIsCalled() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
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
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(), bookmarkManager: bookmarkManager)
        var didCallDismiss = false
        sut.folderName = "DuckDuckGo"

        // WHEN
        sut.addOrSave {
            didCallDismiss = true
        }

        // THEN
        XCTAssertTrue(didCallDismiss)
    }

    func testShouldAskBookmarkStoreToSaveFolderWhenAddOrSaveIsCalledAndModeIsAdd() {
        // GIVEN
        let folder = BookmarkFolder(id: #file, title: #function)
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: folder), bookmarkManager: bookmarkManager)
        sut.folderName = #function
        XCTAssertFalse(bookmarkStoreMock.saveFolderCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolder)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolder)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.updateFolderCalled)
        XCTAssertTrue(bookmarkStoreMock.saveFolderCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolder?.title, #function)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolder, folder)
    }

    func testShouldAskBookmarkStoreToUpdateFolderWhenNameIsChanged() {
        // GIVEN
        let folder = BookmarkFolder(id: #file, title: #function)
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: nil), bookmarkManager: bookmarkManager)
        sut.folderName = "TEST"
        XCTAssertFalse(bookmarkStoreMock.updateFolderCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolder)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertTrue(bookmarkStoreMock.updateFolderCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolder?.title, "TEST")
    }

    func testShouldNotAskBookmarkStoreToUpdateFolderWhenNameIsNotChanged() {
        // GIVEN
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: .mock, parentFolder: nil), bookmarkManager: bookmarkManager)
        XCTAssertFalse(bookmarkStoreMock.updateFolderCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolder)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveFolderCalled)
        XCTAssertFalse(bookmarkStoreMock.updateFolderCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolder?.title)
    }

    func testShouldAskBookmarkStoreToMoveFolderToSubfolderWhenSelectedFolderIsDifferentFromOriginalFolder() {
        // GIVEN
        let location = BookmarkFolder(id: #file, title: #function)
        let folder = BookmarkFolder.mock
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: nil), bookmarkManager: bookmarkManager)
        sut.selectedFolder = location
        XCTAssertFalse(bookmarkStoreMock.updateFolderAndMoveToParentCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolder)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveFolderCalled)
        XCTAssertTrue(bookmarkStoreMock.updateFolderAndMoveToParentCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolder, folder)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .parent(uuid: #file))
    }

    func testShouldAskBookmarkStoreToMoveFolderToRootFolderWhenSelectedFolderIsDifferentFromOriginalFolder() {
        // GIVEN
        let folder = BookmarkFolder.mock
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: .mock), bookmarkManager: bookmarkManager)
        sut.selectedFolder = nil
        XCTAssertFalse(bookmarkStoreMock.updateFolderAndMoveToParentCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolder)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveFolderCalled)
        XCTAssertTrue(bookmarkStoreMock.updateFolderAndMoveToParentCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolder, folder)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .root)
    }

    func testShouldNotAskBookmarkStoreToMoveFolderWhenSelectedFolderIsNotDifferentFromOriginalFolder() {
        // GIVEN
        let folder = BookmarkFolder.mock
        let sut = AddEditBookmarkFolderDialogViewModel(mode: .edit(folder: folder, parentFolder: nil), bookmarkManager: bookmarkManager)
        sut.selectedFolder = nil
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.addOrSave {}

        // THEN
        XCTAssertFalse(bookmarkStoreMock.saveFolderCalled)
        XCTAssertFalse(bookmarkStoreMock.moveObjectUUIDCalled)
        XCTAssertNil(bookmarkStoreMock.capturedObjectUUIDs)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)
    }

}
