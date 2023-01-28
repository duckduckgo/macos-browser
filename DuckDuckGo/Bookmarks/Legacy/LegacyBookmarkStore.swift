//
//  BookmarkStore.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Foundation
import CoreData
import Cocoa
import os.log

final class LegacyBookmarkStore {

    enum Constants {
        static let rootFolderUUID = "87E09C05-17CB-4185-9EDF-8D1AF4312BAF"
        static let favoritesFolderUUID = "23B11CC4-EA56-4937-8EC1-15854109AE35"
    }

    init() {
        sharedInitialization()
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        sharedInitialization()
    }

    private func sharedInitialization() {
        // TODO: migration
    }

    enum BookmarkStoreError: Error {
        case storeDeallocated
        case insertFailed
        case noObjectId
        case badObjectId
        case asyncFetchFailed
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Bookmark")

}

//fileprivate extension BookmarkManagedObject {
//
//    func update(with baseEntity: BaseBookmarkEntity, favoritesFolder: BookmarkManagedObject?) {
//        if let bookmark = baseEntity as? Bookmark {
//            update(with: bookmark, favoritesFolder: favoritesFolder)
//        } else if let folder = baseEntity as? BookmarkFolder {
//            update(with: folder)
//        } else {
//            assertionFailure("\(#file): Failed to cast base entity to Bookmark or BookmarkFolder")
//        }
//    }
//
//    func update(with bookmark: Bookmark, favoritesFolder: BookmarkManagedObject?) {
//        id = bookmark.id
//        urlEncrypted = bookmark.url as NSURL?
//        titleEncrypted = bookmark.title as NSString
//        self.favoritesFolder = bookmark.isFavorite ? favoritesFolder : nil
//        isFolder = false
//    }
//
//    func update(with folder: BookmarkFolder) {
//        id = folder.id
//        titleEncrypted = folder.title as NSString
//        favoritesFolder = nil
//        isFolder = true
//    }
//
//}
//
//fileprivate extension BookmarkManagedObject {
//
//    var isInvalid: Bool {
//        if titleEncrypted == nil {
//            return true
//        }
//
//        return false
//    }
//
//}
