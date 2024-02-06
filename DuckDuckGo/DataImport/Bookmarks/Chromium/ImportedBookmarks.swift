//
//  ImportedBookmarks.swift
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

struct ImportedBookmarks: Codable, Equatable {

    struct BookmarkOrFolder: Codable, Equatable {
        let name: String

        struct EntityType: RawRepresentable, Codable, Equatable {
            let rawValue: String

            static let bookmark = EntityType(rawValue: "bookmark")
            static let folder = EntityType(rawValue: "folder")
            static let url = EntityType(rawValue: "url")
        }
        let type: EntityType?
        let urlString: String?
        var isDDGFavorite: Bool = false

        let children: [BookmarkOrFolder]?

        static func bookmark(name: String, urlString: String?, isDDGFavorite: Bool) -> BookmarkOrFolder {
            .init(name: name, type: .bookmark, urlString: urlString, children: nil, isDDGFavorite: isDDGFavorite)
        }

        static func folder(name: String, children: [BookmarkOrFolder]) -> BookmarkOrFolder {
            .init(name: name, type: .folder, urlString: nil, children: children)
        }

        var url: URL? {
            if let url = self.urlString {
                return URL(string: url)
            }

            return nil
        }

        var isFolder: Bool {
            return type == .folder
        }

        fileprivate var numberOfBookmarks: Int {
            if isFolder {
                return (children ?? []).reduce(0, { $0 + $1.numberOfBookmarks })
            }
            return 1
        }

        enum CodingKeys: String, CodingKey {
            case name
            case type
            case urlString = "url"
            case children
        }

        init(name: String, type: EntityType, urlString: String?, children: [BookmarkOrFolder]?, isDDGFavorite: Bool = false) {
            self.name = name.trimmingWhitespace()
            self.type = type
            self.urlString = urlString
            self.children = children
            self.isDDGFavorite = isDDGFavorite
        }
    }

    struct TopLevelFolders: Codable, Equatable {
        let bookmarkBar: BookmarkOrFolder?
        let otherBookmarks: BookmarkOrFolder?
        let syncedBookmarks: BookmarkOrFolder?

        enum CodingKeys: String, CodingKey {
            case bookmarkBar = "bookmark_bar"
            case otherBookmarks = "other"
            case syncedBookmarks = "synced"
        }
    }

    let topLevelFolders: TopLevelFolders

    var numberOfBookmarks: Int {
        [topLevelFolders.bookmarkBar, topLevelFolders.otherBookmarks, topLevelFolders.syncedBookmarks]
            .reduce(0) { $0 + ($1?.numberOfBookmarks ?? 0) }
    }

    enum CodingKeys: String, CodingKey {
        case topLevelFolders = "roots"
    }

}
