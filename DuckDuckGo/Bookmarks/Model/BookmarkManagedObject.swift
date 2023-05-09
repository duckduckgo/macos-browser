//
//  BookmarkManagedObject.swift
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

import Foundation
import CoreData

extension BookmarkManagedObject {

    public static func entity(in context: NSManagedObjectContext) -> NSEntityDescription {
        NSEntityDescription.entity(forEntityName: "BookmarkManagedObject", in: context)!
    }

    enum BookmarkError: Error {
        case mustExistInsideRootFolder
        case folderStructureHasCycle
        case folderHasURL
        case bookmarkRequiresURL
        case invalidFavoritesFolder
    }

    public var mutableChildren: NSMutableOrderedSet {
        return mutableOrderedSetValue(forKey: "children")
    }

    public var mutableFavorites: NSMutableOrderedSet {
        return mutableOrderedSetValue(forKey: "favorites")
    }

    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validate()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validate()
    }

    // MARK: - Private

    func validate() throws {
        try validateThatEntitiesExistInsideTheRootFolder()
        try validateBookmarkURLRequirement()
        try validateThatFoldersDoNotHaveURLs()
        try validateThatFolderHierarchyHasNoCycles()
        try validateFavoritesFolder()
    }

    func validateThatEntitiesExistInsideTheRootFolder() throws {
        if parentFolder == nil, ![UUID(uuidString: LegacyBookmarkStore.Constants.favoritesFolderUUID),
                                  UUID(uuidString: LegacyBookmarkStore.Constants.rootFolderUUID)].contains(id) {
            throw BookmarkError.mustExistInsideRootFolder
        }
    }

    func validateBookmarkURLRequirement() throws {
        if !isFolder, urlEncrypted == nil {
            throw BookmarkError.bookmarkRequiresURL
        }
    }

    func validateFavoritesFolder() throws {
        if let favoritesFolderID = favoritesFolder?.id, favoritesFolderID != UUID(uuidString: LegacyBookmarkStore.Constants.favoritesFolderUUID) {
            throw BookmarkError.invalidFavoritesFolder
        }
    }

    func validateThatFoldersDoNotHaveURLs() throws {
        if isFolder, urlEncrypted != nil {
            throw BookmarkError.folderHasURL
        }
    }

    /// Validates that folders do not reference any of their ancestors, causing a cycle.
    func validateThatFolderHierarchyHasNoCycles() throws {
        if let parent = parentFolder, parent.id == self.id {
            throw BookmarkError.folderStructureHasCycle
        }

        var parentUUIDs = Set<UUID>()
        var currentFolder: BookmarkManagedObject? = self

        while let current = currentFolder {
            if current.parentFolder?.id == self.id {
                throw BookmarkError.folderStructureHasCycle
            }

            if let folderID = current.id {
                parentUUIDs.insert(folderID)
            }

            currentFolder = currentFolder?.parentFolder
        }

        let childUUIDs = Set(self.children?.compactMap { child -> UUID? in
            let bookmark = child as? BookmarkManagedObject
            return bookmark?.id
        } ?? [UUID]())

        if !childUUIDs.isDisjoint(with: parentUUIDs) {
            throw BookmarkError.folderStructureHasCycle
        }
    }

}
