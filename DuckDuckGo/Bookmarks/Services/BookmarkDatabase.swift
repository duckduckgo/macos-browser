//
//  BookmarkDatabase.swift
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
import Bookmarks
import Persistence

public final class BookmarkDatabase {

    public static let shared = BookmarkDatabase()

    public let db: CoreDataDatabase

    public static var defaultDBLocation: URL = URL.sandboxApplicationSupportURL
    public static var defaultDBFileURL: URL = {
        return defaultDBLocation.appendingPathComponent("Bookmarks.sqlite", conformingTo: .database)
    }()
    public var preFormFactorSpecificFavoritesFolderOrder: [String]?

    init(db: CoreDataDatabase = make(location: URL.sandboxApplicationSupportURL)) {
        self.db = db
    }

    public static func make(location: URL) -> CoreDataDatabase {
        let bundle = Bookmarks.bundle
        guard let model = CoreDataDatabase.loadModel(from: bundle, named: "BookmarksModel") else {
            fatalError("Failed to load model")
        }

        return CoreDataDatabase(name: "Bookmarks",
                                containerLocation: location,
                                model: model)
    }
}
