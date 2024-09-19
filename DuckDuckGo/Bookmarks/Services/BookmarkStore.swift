//
//  BookmarkStore.swift
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

enum BookmarkStoreFetchPredicateType {
    case bookmarks
    case topLevelEntities
    case favorites
}

enum ParentFolderType: Equatable {
    case root
    case parent(uuid: String)
}

struct BookmarksImportSummary: Equatable {
    var successful: Int
    var duplicates: Int
    var failed: Int

    static func += (left: inout BookmarksImportSummary, right: BookmarksImportSummary) {
        left.successful += right.successful
        left.duplicates += right.duplicates
        left.failed += right.failed
    }
}

protocol BookmarkStore {

    func applyFavoritesDisplayMode(_ configuration: FavoritesDisplayMode)

    func loadAll(type: BookmarkStoreFetchPredicateType, completion: @escaping ([BaseBookmarkEntity]?, Error?) -> Void)
    func save(bookmark: Bookmark, parent: BookmarkFolder?, index: Int?, completion: @escaping (Bool, Error?) -> Void)
    func saveBookmarks(for websitesInfo: [WebsiteInfo], inNewFolderNamed folderName: String, withinParentFolder parent: ParentFolderType)
    func save(folder: BookmarkFolder, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void)
    func remove(objectsWithUUIDs: [String], completion: @escaping (Bool, Error?) -> Void)
    func restore(_ objects: [BaseBookmarkEntity], completion: @escaping (Error?) -> Void)
    func update(bookmark: Bookmark)
    func bookmarkEntities(withIds ids: [String]) -> [BaseBookmarkEntity]?
    func update(folder: BookmarkFolder)
    func update(folder: BookmarkFolder, andMoveToParent parent: ParentFolderType)
    func add(objectsWithUUIDs: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void)
    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void)
    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool
    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: ParentFolderType, completion: @escaping (Error?) -> Void)
    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void)
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarksImportSummary
    func handleFavoritesAfterDisablingSync()
}
extension BookmarkStore {

    func loadAll(type: BookmarkStoreFetchPredicateType) async throws -> [BaseBookmarkEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            loadAll(type: type) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: result ?? [])
            }
        }
    }

    func bookmarkFolder(withId id: String) -> BookmarkFolder? {
        bookmarkEntities(withIds: [id])?.first as? BookmarkFolder
    }

    func save(folder: BookmarkFolder, parent: BookmarkFolder?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            save(folder: folder, parent: parent) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }

    func save(bookmark: Bookmark, parent: BookmarkFolder?, index: Int?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            save(bookmark: bookmark, parent: parent, index: index) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }

    func remove(objectsWithUUIDs uuids: [String]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            remove(objectsWithUUIDs: uuids) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }

    func restore(_ objects: [BaseBookmarkEntity]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            restore(objects) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume()
            }
        }
    }

}
