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

        let children: [BookmarkOrFolder]?

        var url: URL? {
            if let url = self.urlString {
                return URL(string: url)
            }

            return nil
        }

        var isFolder: Bool {
            return type == "folder"
        }

        // There's no guarantee that imported bookmarks will have a URL, this is used to filter them out during import
        var isInvalidBookmark: Bool {
            return !isFolder && url == nil
        }

        enum CodingKeys: String, CodingKey {
            case name
            case type
            case urlString = "url"
            case children
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

    enum CodingKeys: String, CodingKey {
        case topLevelFolders = "roots"
    }

}
