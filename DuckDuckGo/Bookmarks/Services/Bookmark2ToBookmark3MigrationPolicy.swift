//
//  Bookmark2ToBookmark3MigrationPolicy.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

internal class Bookmark2ToBookmark3MigrationPolicy: NSEntityMigrationPolicy {

    private var favoritesFolder: NSManagedObject?

    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        try super.begin(mapping, with: manager)

        self.favoritesFolder = BookmarkManagedObject.createFavoritesFolder(in: manager.destinationContext)
        try manager.destinationContext.save()
    }

    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        guard let favoritesFolder = favoritesFolder else {
            assertionFailure("Failed to create Favorites Folder")
            return
        }

        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        guard let bookmark = manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sInstance]).first else {
            fatalError("Must return Bookmark")
        }

        if sInstance.value(forKey: "isFavorite") as? Bool == true {
            bookmark.setValue(favoritesFolder, forKey: "favoritesFolder")
        } else {
            bookmark.setValue(nil, forKey: "favoritesFolder")
        }
    }
}
