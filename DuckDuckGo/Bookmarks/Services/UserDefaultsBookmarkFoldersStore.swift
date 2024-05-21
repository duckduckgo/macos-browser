//
//  UserDefaultsBookmarkFoldersStore.swift
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

import Foundation

/// A type used to provide the ID of the folder where all tabs were last saved.
protocol BookmarkFoldersStore: AnyObject {
    /// The ID of the folder where all bookmarks from the last session were saved.
    var lastBookmarkAllTabsFolderIdUsed: String? { get set }
}

final class UserDefaultsBookmarkFoldersStore: BookmarkFoldersStore {

    enum Keys {
        static let bookmarkAllTabsFolderUsedKey = "bookmarks.all-tabs.last-used-folder"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var lastBookmarkAllTabsFolderIdUsed: String? {
        get {
            userDefaults.string(forKey: Keys.bookmarkAllTabsFolderUsedKey)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.bookmarkAllTabsFolderUsedKey)
        }
    }

}
