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

#if DEBUG

import Bookmarks
import Foundation

public final class BookmarkStoreMock: BookmarkStore {

    init(loadAllCalled: Bool = false, bookmarks: [BaseBookmarkEntity]? = nil, loadError: Error? = nil, saveBookmarkCalled: Bool = false, saveBookmarkSuccess: Bool = true, saveBookmarkError: Error? = nil, saveFolderCalled: Bool = false, saveFolderSuccess: Bool = true, saveFolderError: Error? = nil, removeCalled: Bool = false, removeSuccess: Bool = true, removeError: Error? = nil, updateBookmarkCalled: Bool = false, updateFolderCalled: Bool = false, addChildCalled: Bool = false, updateObjectsCalled: Bool = false, importBookmarksCalled: Bool = false, canMoveObjectWithUUIDCalled: Bool = false, moveObjectUUIDCalled: Bool = false, updateFavoriteIndexCalled: Bool = false) {
        self.loadAllCalled = loadAllCalled
        self.bookmarks = bookmarks
        self.loadError = loadError
        self.saveBookmarkCalled = saveBookmarkCalled
        self.saveBookmarkSuccess = saveBookmarkSuccess
        self.saveBookmarkError = saveBookmarkError
        self.saveFolderCalled = saveFolderCalled
        self.saveFolderSuccess = saveFolderSuccess
        self.saveFolderError = saveFolderError
        self.removeCalled = removeCalled
        self.removeSuccess = removeSuccess
        self.removeError = removeError
        self.updateBookmarkCalled = updateBookmarkCalled
        self.updateFolderCalled = updateFolderCalled
        self.addChildCalled = addChildCalled
        self.updateObjectsCalled = updateObjectsCalled
        self.importBookmarksCalled = importBookmarksCalled
        self.canMoveObjectWithUUIDCalled = canMoveObjectWithUUIDCalled
        self.moveObjectUUIDCalled = moveObjectUUIDCalled
        self.updateFavoriteIndexCalled = updateFavoriteIndexCalled
    }

    var capturedFolder: BookmarkFolder?
    var capturedParentFolder: BookmarkFolder?
    var capturedParentFolderType: ParentFolderType?
    var capturedBookmark: Bookmark?

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
        capturedParentFolder = parent
        capturedBookmark = bookmark
        completion(saveBookmarkSuccess, saveBookmarkError)
    }

    var saveFolderCalled = false
    var saveFolderSuccess = true
    var saveFolderError: Error?
    func save(folder: BookmarkFolder, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void) {
        saveFolderCalled = true
        capturedFolder = folder
        capturedParentFolder = parent
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
        capturedBookmark = bookmark
    }

    var bookmarkFolderWithIdCalled = false
    var capturedFolderId: String?
    var bookmarkFolder: BookmarkFolder?
    func bookmarkFolder(withId id: String) -> BookmarkFolder? {
        bookmarkFolderWithIdCalled = true
        capturedFolderId = id
        return bookmarkFolder
    }

    var updateFolderCalled = false
    func update(folder: BookmarkFolder) {
        updateFolderCalled = true
        capturedFolder = folder
    }

    var updateFolderAndMoveToParentCalled = false
    func update(folder: BookmarkFolder, andMoveToParent parent: ParentFolderType) {
        updateFolderAndMoveToParentCalled = true
        capturedFolder = folder
        capturedParentFolderType = parent
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
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarksImportSummary {
        importBookmarksCalled = true
        return BookmarksImportSummary(successful: 0, duplicates: 0, failed: 0)
    }

    var saveBookmarksInNewFolderNamedCalled = false
    var capturedWebsitesInfo: [WebsiteInfo]?
    var capturedNewFolderName: String?
    func saveBookmarks(for websitesInfo: [WebsiteInfo], inNewFolderNamed folderName: String, withinParentFolder parent: ParentFolderType) {
        saveBookmarksInNewFolderNamedCalled = true
        capturedWebsitesInfo = websitesInfo
        capturedNewFolderName = folderName
        capturedParentFolderType = parent
    }

    var canMoveObjectWithUUIDCalled = false
    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool {
        canMoveObjectWithUUIDCalled = true
        return true
    }

    var moveObjectUUIDCalled = false
    var capturedObjectUUIDs: [String]?
    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: ParentFolderType, completion: @escaping (Error?) -> Void) {
        moveObjectUUIDCalled = true
        capturedObjectUUIDs = objectUUIDs
        capturedParentFolderType = withinParentFolder
    }

    var updateFavoriteIndexCalled = false
    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void) {
        updateFavoriteIndexCalled = true
    }

    func applyFavoritesDisplayMode(_ configuration: FavoritesDisplayMode) {}
    func handleFavoritesAfterDisablingSync() {}
}

extension ParentFolderType: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.root, .root):
            return true
        case (.parent(let lhsValue), .parent(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

#endif
