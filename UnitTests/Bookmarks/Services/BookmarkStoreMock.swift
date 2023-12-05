//
//  BookmarkStoreMock.swift
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

import Bookmarks
import Foundation

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class BookmarkStoreMock: BookmarkStore {

    var loadAllCalled = false
    var bookmarks: [BaseBookmarkEntity]?
    var loadError: Error?
    func loadAll(type: BookmarkStoreFetchPredicateType, completion: @escaping ([BaseBookmarkEntity]?, Error?) -> Void) {
        loadAllCalled = true
        completion(bookmarks, loadError)
    }

    var saveBookmarkCalled = false
    var saveBookmarkSuccess = true
    var saveBookmarkError: Error?
    func save(bookmark: Bookmark, parent: BookmarkFolder?, index: Int?, completion: @escaping (Bool, Error?) -> Void) {
        saveBookmarkCalled = true
        bookmarks?.append(bookmark)
        completion(saveBookmarkSuccess, saveBookmarkError)
    }

    var saveFolderCalled = false
    var saveFolderSuccess = true
    var saveFolderError: Error?
    func save(folder: BookmarkFolder, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void) {
        saveFolderCalled = true
        completion(saveFolderSuccess, saveFolderError)
    }

    var removeCalled = false
    var removeSuccess = true
    var removeError: Error?
    func remove(objectsWithUUIDs uuids: [String], completion: @escaping (Bool, Error?) -> Void) {
        removeCalled = true

        // For the purpose of the mock, only remove bookmarks if `removeSuccess` is true.
        if removeSuccess {
            bookmarks?.removeAll { uuids.contains($0.id) }
        }

        completion(removeSuccess, removeError)
    }

    var updateBookmarkCalled = false
    func update(bookmark: Bookmark) {
        if let index = bookmarks?.firstIndex(where: { $0.id == bookmark.id}) {
            bookmarks![index] = bookmark
        }

        updateBookmarkCalled = true
    }

    var updateFolderCalled = false
    func update(folder: BookmarkFolder) {
        updateFolderCalled = true
    }

    var addChildCalled = false
    func add(objectsWithUUIDs: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        addChildCalled = true
    }

    var updateObjectsCalled = false
    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {
        updateObjectsCalled = true
    }

    var importBookmarksCalled = false
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarkImportResult {
        importBookmarksCalled = true
        return BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)
    }

    var canMoveObjectWithUUIDCalled = false
    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool {
        canMoveObjectWithUUIDCalled = true
        return true
    }

    var moveObjectUUIDCalled = false
    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: DuckDuckGo_Privacy_Browser.ParentFolderType, completion: @escaping (Error?) -> Void) {
        moveObjectUUIDCalled = true
    }

    var updateFavoriteIndexCalled = false
    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void) {
        updateFavoriteIndexCalled = true
    }

    func applyFavoritesDisplayMode(_ configuration: FavoritesDisplayMode) {}
    func handleFavoritesAfterDisablingSync() {}
}
