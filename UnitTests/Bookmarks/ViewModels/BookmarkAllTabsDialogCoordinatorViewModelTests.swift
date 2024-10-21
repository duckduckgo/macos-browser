//
//  BookmarkAllTabsDialogCoordinatorViewModelTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class BookmarkAllTabsDialogCoordinatorViewModelTests: XCTestCase {
    private var sut: BookmarkAllTabsDialogCoordinatorViewModel<BookmarkAllTabsDialogViewModelMock, AddEditBookmarkFolderDialogViewModelMock>!
    private var bookmarkAllTabsViewModelMock: BookmarkAllTabsDialogViewModelMock!
    private var bookmarkFolderViewModelMock: AddEditBookmarkFolderDialogViewModelMock!
    private var cancellables: Set<AnyCancellable>!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()

        cancellables = []
        bookmarkAllTabsViewModelMock = .init()
        bookmarkFolderViewModelMock = .init()
        sut = .init(bookmarkModel: bookmarkAllTabsViewModelMock, folderModel: bookmarkFolderViewModelMock)
    }

    override func tearDownWithError() throws {
        cancellables = nil
        bookmarkAllTabsViewModelMock = nil
        bookmarkFolderViewModelMock = nil
        sut = nil
        try super.tearDownWithError()
    }

    func testWhenInitThenViewStateIsBookmarkAllTabs() {
        XCTAssertEqual(sut.viewState, .bookmarkAllTabs)
    }

    func testWhenDismissActionIsCalledThenViewStateIsBookmarkAllTabs() {
        // GIVEN
        sut.addFolderAction()
        XCTAssertEqual(sut.viewState, .addFolder)

        // WHEN
        sut.dismissAction()

        // THEN
        XCTAssertEqual(sut.viewState, .bookmarkAllTabs)

    }

    @MainActor
    func testWhenAddFolderActionIsCalledThenSetSelectedFolderOnFolderViewModelIsCalledAndReturnAddFolderViewState() {
        // GIVEN
        let folder = BookmarkFolder(id: "1", title: "Folder")
        bookmarkAllTabsViewModelMock.selectedFolder = folder
        XCTAssertNil(bookmarkFolderViewModelMock.selectedFolder)
        XCTAssertEqual(sut.viewState, .bookmarkAllTabs)

        // WHEN
        sut.addFolderAction()

        // THEN
        XCTAssertEqual(bookmarkFolderViewModelMock.selectedFolder, folder)
        XCTAssertEqual(sut.viewState, .addFolder)
    }

    func testWhenBookmarkModelChangesThenReceiveEvent() {
        // GIVEN
        let expectation = self.expectation(description: #function)
        var didCallChangeValue = false
        sut.objectWillChange.sink { _ in
            didCallChangeValue = true
            expectation.fulfill()
        }
        .store(in: &cancellables)

        // WHEN
        sut.bookmarkModel.objectWillChange.send()

        // THEN
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(didCallChangeValue)
    }

    func testWhenBookmarkFolderModelChangesThenReceiveEvent() {
        // GIVEN
        let expectation = self.expectation(description: #function)
        var didCallChangeValue = false
        sut.objectWillChange.sink { _ in
            didCallChangeValue = true
            expectation.fulfill()
        }
        .store(in: &cancellables)

        // WHEN
        sut.folderModel.objectWillChange.send()

        // THEN
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(didCallChangeValue)
    }

    @MainActor
    func testWhenAddFolderPublisherSendsEventThenSelectedFolderOnBookmarkAllTabsViewModelIsSet() {
        // GIVEN
        let expectation = self.expectation(description: #function)
        bookmarkAllTabsViewModelMock.selectedFolderExpectation = expectation
        let folder = BookmarkFolder(id: "ABCDE", title: #function)
        XCTAssertNil(bookmarkAllTabsViewModelMock.selectedFolder)

        // WHEN
        sut.folderModel.subject.send(folder)

        // THEN
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(bookmarkAllTabsViewModelMock.selectedFolder, folder)
    }

    // MARK: - Integration Test

    @MainActor
    func testWhenAddFolderMultipleTimesThenFolderListIsUpdatedAndSelectedFolderIsNil() {
        // GIVEN
        let expectation = self.expectation(description: #function)
        let folder = BookmarkFolder(id: "1", title: "Folder")
        bookmarkAllTabsViewModelMock.selectedFolder = folder
        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [folder])
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        let folderModel = AddEditBookmarkFolderDialogViewModel(mode: .add(parentFolder: nil), bookmarkManager: bookmarkManager)
        let sut = BookmarkAllTabsDialogCoordinatorViewModel(bookmarkModel: bookmarkAllTabsViewModelMock, folderModel: folderModel)
        let c = folderModel.$folders
            .dropFirst(2) // Not interested in the first two events. 1.subscribing to $folders and 2. subscribing to $list.
            .sink { folders in
                expectation.fulfill()
        }

        XCTAssertNil(folderModel.selectedFolder)

        // Tap Add Folder
        sut.addFolderAction()
        XCTAssertEqual(sut.viewState, .addFolder)
        XCTAssertTrue(folderModel.folderName.isEmpty)
        XCTAssertEqual(folderModel.selectedFolder, folder)

        // Create a new folder
        folderModel.folderName = #function
        folderModel.addOrSave {}

        // Add folder again
        sut.addFolderAction()

        // THEN
        withExtendedLifetime(c) {}
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(sut.viewState, .addFolder)
        XCTAssertTrue(folderModel.folderName.isEmpty)
    }

}
