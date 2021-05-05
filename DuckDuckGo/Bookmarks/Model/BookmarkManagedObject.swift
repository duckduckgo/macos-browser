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

    enum Error: Swift.Error {
        case folderRecursion
        case folderBookmarkDistinction
        case bookmarkURLRequirement
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
        try validateBookmarkURLRequirement()
        try validateFolderBookmarkDistinction()
        try validateFolderStructure()
    }

    func validateBookmarkURLRequirement() throws {
        if !isFolder, urlEncrypted == nil {
            throw Error.bookmarkURLRequirement
        }
    }

    func validateFolderBookmarkDistinction() throws {
        if isFolder, urlEncrypted != nil {
            throw Error.folderBookmarkDistinction
        }
    }

    func validateFolderStructure() throws {
        if let parent = parentFolder, parent.id == self.id {
            throw Error.folderRecursion
        }

        var parentUUIDs = Set<UUID>()
        var currentFolder: BookmarkManagedObject? = self

        while let current = currentFolder {
            if current.parentFolder?.id == self.id {
                throw Error.folderRecursion
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
            throw Error.folderRecursion
        }
    }

}
