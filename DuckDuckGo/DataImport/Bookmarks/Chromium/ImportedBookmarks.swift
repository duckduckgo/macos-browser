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

struct ImportedBookmarks: Decodable {

    struct BookmarkOrFolder: Decodable {
        let name: String
        let type: String
        let urlString: String?
        let isDDGFavorite: Bool

        let children: [BookmarkOrFolder]?

        static func bookmark(name: String, urlString: String?, isDDGFavorite: Bool) -> BookmarkOrFolder {
            .init(name: name, type: "bookmark", urlString: urlString, children: nil, isDDGFavorite: isDDGFavorite)
        }

        static func folder(name: String, children: [BookmarkOrFolder]) -> BookmarkOrFolder {
            .init(name: name, type: "folder", urlString: nil, children: children)
        }

        var url: URL? {
            if let url = self.urlString {
                return URL(string: url)
            }

            return nil
        }

        var isFolder: Bool {
            return type == "folder"
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            type = try container.decode(String.self, forKey: .type)
            urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
            children = try container.decodeIfPresent([BookmarkOrFolder].self, forKey: .children)
            isDDGFavorite = false
        }

        init(name: String, type: String, urlString: String?, children: [BookmarkOrFolder]?, isDDGFavorite: Bool = false) {
            self.name = name.trimmingWhitespace()
            self.type = type
            self.urlString = urlString
            self.children = children
            self.isDDGFavorite = isDDGFavorite
        }
    }

    struct TopLevelFolders: Decodable {
        let bookmarkBar: BookmarkOrFolder
        let otherBookmarks: BookmarkOrFolder

        enum CodingKeys: String, CodingKey {
            case bookmarkBar = "bookmark_bar"
            case otherBookmarks = "other"
        }
    }

    let topLevelFolders: TopLevelFolders

    var numberOfBookmarks: Int {
        topLevelFolders.bookmarkBar.numberOfBookmarks + topLevelFolders.otherBookmarks.numberOfBookmarks
    }

    enum CodingKeys: String, CodingKey {
        case topLevelFolders = "roots"
    }

}
