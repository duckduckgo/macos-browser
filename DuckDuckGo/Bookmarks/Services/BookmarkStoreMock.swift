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
import BrowserServicesKit

final class BookmarkStoreMock: BookmarkStore, CustomDebugStringConvertible {

    private let store: LocalBookmarkStore?

    init(contextProvider: (() -> NSManagedObjectContext)? = nil, loadAllCalled: Bool = false, bookmarks: [BaseBookmarkEntity]? = nil, loadError: Error? = nil, removeError: Error? = nil, updateBookmarkCalled: Bool = false, updateFolderCalled: Bool = false, addChildCalled: Bool = false, updateObjectsCalled: Bool = false, importBookmarksCalled: Bool = false, canMoveObjectWithUUIDCalled: Bool = false, moveObjectUUIDCalled: Bool = false, updateFavoriteIndexCalled: Bool = false) {
        self.loadAllCalled = loadAllCalled
        self.bookmarks = bookmarks
        self.loadError = loadError
        self.removeError = removeError
        self.updateBookmarkCalled = updateBookmarkCalled
        self.updateFolderCalled = updateFolderCalled
        self.addChildCalled = addChildCalled
        self.updateObjectsCalled = updateObjectsCalled
        self.importBookmarksCalled = importBookmarksCalled
        self.canMoveObjectWithUUIDCalled = canMoveObjectWithUUIDCalled
        self.moveObjectUUIDCalled = moveObjectUUIDCalled
        self.updateFavoriteIndexCalled = updateFavoriteIndexCalled

        self.store = contextProvider.map { LocalBookmarkStore(contextProvider: $0) }
        if let bookmarks, !bookmarks.isEmpty {
            var entities = [BaseBookmarkEntity]()
            var queue = bookmarks
            while !queue.isEmpty {
                let entity = queue.removeFirst()
                entities.append(entity)
                if let folder = entity as? BookmarkFolder {
                    queue.append(contentsOf: folder.children)
                }
            }
            store?.save(entitiesAtIndices: entities.map { ($0, nil, nil) }, completion: { _ in })
        }
    }

    var capturedFolder: BookmarkFolder?
    var capturedParentFolder: BookmarkFolder?
    var capturedParentFolderType: ParentFolderType?
    var capturedBookmark: Bookmark?

    var loadAllCalled = false
    var bookmarks: [BaseBookmarkEntity]?
    var loadError: Error?
    func loadAll(type: BookmarkStoreFetchPredicateType, completion: @escaping ([BaseBookmarkEntity]?, Error?) -> Void) {
        func flattenedBookmarks(_ entities: [BaseBookmarkEntity]) -> [BaseBookmarkEntity] {
            var result = [BaseBookmarkEntity]()
            for entity in entities {
                if let bookmark = entity as? Bookmark {
                    result.append(bookmark)
                } else if let folder = entity as? BookmarkFolder {
                    result.append(contentsOf: flattenedBookmarks(folder.children))
                }
            }
            return result
        }

        loadAllCalled = true
        store?.loadAll(type: type, completion: completion) ?? {
            let result: [BaseBookmarkEntity]
            switch type {
            case .bookmarks:
                result = flattenedBookmarks(bookmarks ?? [])
            case .favorites:
                result = flattenedBookmarks(bookmarks ?? []).filter { ($0 as? Bookmark)!.isFavorite }
            case .topLevelEntities:
                result = bookmarks ?? []
            }
            completion(result, loadError)
        }()
    }

    var saveBookmarkSuccess: Bool {
        get {
            saveEntitiesError == nil
        }
        set {
            saveEntitiesError = newValue ? nil : NSError(domain: "SaveBookmarkError", code: 1)
        }
    }
    var saveEntitiesAtIndicesCalledWith: [(entity: BaseBookmarkEntity, index: Int?, indexInFavoritesArray: Int?)]?
    var saveBookmarkCalled: Bool {
        saveEntitiesAtIndicesCalledWith?.contains(where: { $0.entity is Bookmark }) == true
    }
    var saveFolderSuccess: Bool {
        get {
            saveEntitiesError == nil
        }
        set {
            saveEntitiesError = newValue ? nil : NSError(domain: "SaveFolderError", code: 1)
        }
    }
    var saveFolderCalled: Bool {
        saveEntitiesAtIndicesCalledWith?.contains(where: { $0.entity is BookmarkFolder }) == true
    }
    func savedFolder(withTitle title: String) -> BookmarkFolder? {
        saveEntitiesAtIndicesCalledWith?.first(where: { $0.entity.title == title })?.entity as? BookmarkFolder
    }
    var saveEntitiesError: Error?
    func save(entitiesAtIndices: [(entity: BaseBookmarkEntity, index: Int?, indexInFavoritesArray: Int?)], completion: @escaping ((any Error)?) -> Void) {
        saveEntitiesAtIndicesCalledWith = entitiesAtIndices
        guard saveBookmarkSuccess else {
            completion(saveEntitiesError)
            return
        }
        let ids = Set(entitiesAtIndices.map(\.entity.id))
        if let store {
            store.save(entitiesAtIndices: entitiesAtIndices, completion: completion)
            bookmarks?.removeAll(where: { ids.contains($0.id) })
            bookmarks?.append(contentsOf: entitiesAtIndices.map(\.entity))
        } else {
            bookmarks?.removeAll(where: { ids.contains($0.id) })
            bookmarks?.append(contentsOf: entitiesAtIndices.map(\.entity))
            completion(saveEntitiesError)
        }
    }

    var removeCalled: Bool { removeCalledWithIds != nil }
    var removeCalledWithIds: [String]?
    var removeError: Error?
    func remove(objectsWithUUIDs uuids: [String], completion: @escaping (Error?) -> Void) {
        removeCalledWithIds = uuids

        // For the purpose of the mock, only remove bookmarks if `removeSuccess` is true.
        guard removeError == nil else {
            completion(removeError)
            return
        }

        store?.remove(objectsWithUUIDs: uuids, completion: completion) ?? { bookmarks?.removeAll { uuids.contains($0.id) }
            completion(removeError)
        }()
    }

    var updateBookmarkCalled = false
    func update(bookmark: Bookmark) {
        if store == nil, let index = bookmarks?.firstIndex(where: { $0.id == bookmark.id}) {
            bookmarks![index] = bookmark
        }

        updateBookmarkCalled = true
        capturedBookmark = bookmark

        store?.update(bookmark: bookmark)
    }

    var bookmarkFolderWithIdCalled = false
    var capturedEntityIds: [String]?
    var capturedFolderId: String? { capturedEntityIds?.last }
    func bookmarkEntities(withIds ids: [String]) -> [BaseBookmarkEntity]? {
        bookmarkFolderWithIdCalled = true
        capturedEntityIds = ids
        if let store {
            return store.bookmarkEntities(withIds: ids)
        }
        return ids.compactMap { id in bookmarks?.first(where: { $0.id == id }) }
    }

    var updateFolderCalled = false
    func update(folder: BookmarkFolder) {
        updateFolderCalled = true
        capturedFolder = folder
        store?.update(folder: folder)
    }

    var updateFolderAndMoveToParentCalled = false
    func update(folder: BookmarkFolder, andMoveToParent parent: ParentFolderType) {
        updateFolderAndMoveToParentCalled = true
        capturedFolder = folder
        capturedParentFolderType = parent
        store?.update(folder: folder, andMoveToParent: parent)
    }

    var addChildCalled = false
    func add(objectsWithUUIDs: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        addChildCalled = true
        store?.add(objectsWithUUIDs: objectsWithUUIDs, to: parent, completion: completion)
    }

    var updateObjectsCalled = false
    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {
        updateObjectsCalled = true
        store?.update(objectsWithUUIDs: uuids, update: update, completion: completion)
    }

    var importBookmarksCalled = false
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarksImportSummary {
        importBookmarksCalled = true
        return store?.importBookmarks(bookmarks, source: source) ?? BookmarksImportSummary(successful: 0, duplicates: 0, failed: 0)
    }

    var saveBookmarksInNewFolderNamedCalled = false
    var capturedWebsitesInfo: [WebsiteInfo]?
    var capturedNewFolderName: String?
    func saveBookmarks(for websitesInfo: [WebsiteInfo], inNewFolderNamed folderName: String, withinParentFolder parent: ParentFolderType) {
        saveBookmarksInNewFolderNamedCalled = true
        capturedWebsitesInfo = websitesInfo
        capturedNewFolderName = folderName
        capturedParentFolderType = parent
        store?.saveBookmarks(for: websitesInfo, inNewFolderNamed: folderName, withinParentFolder: parent)
    }

    var canMoveObjectWithUUIDCalled = false
    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool {
        canMoveObjectWithUUIDCalled = true
        return store?.canMoveObjectWithUUID(objectUUID: uuid, to: parent) ?? LocalBookmarkStore.validateObjectMove(withUUID: uuid, to: mockBookmarkEntity(from: parent))
    }

    private func mockBookmarkEntity(from folder: BookmarkFolder) -> MockBookmarkEntity {
        MockBookmarkEntity(uuid: folder.id, parent: {
            guard let parentUUID = folder.parentFolderUUID,
                  let folder = self.bookmarkFolder(withId: parentUUID) else { return nil }
            return self.mockBookmarkEntity(from: folder)
        })
    }

    var moveObjectUUIDCalled = false
    var capturedObjectUUIDs: [String]?
    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: ParentFolderType, completion: @escaping (Error?) -> Void) {
        moveObjectUUIDCalled = true
        capturedObjectUUIDs = objectUUIDs
        capturedParentFolderType = withinParentFolder
        store?.move(objectUUIDs: objectUUIDs, toIndex: toIndex, withinParentFolder: withinParentFolder, completion: completion)
    }

    var updateFavoriteIndexCalled = false
    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void) {
        updateFavoriteIndexCalled = true
        store?.moveFavorites(with: objectUUIDs, toIndex: toIndex, completion: completion) ?? {
            completion(nil)
        }()
    }

    func applyFavoritesDisplayMode(_ configuration: FavoritesDisplayMode) {
        store?.applyFavoritesDisplayMode(configuration)
    }
    func handleFavoritesAfterDisablingSync() {
        store?.handleFavoritesAfterDisablingSync()
    }

    struct MockBookmarkEntity: BookmarkEntityProtocol {
        var uuid: String?
        var parent: () -> BookmarkEntityProtocol?
        var bookmarkEntityParent: (any BookmarkEntityProtocol)? {
            parent()
        }
    }

    var debugDescription: String {
        return "<\(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque()): \(store.map { "\($0)" } ?? "<nil>")>"
    }
}

#endif
