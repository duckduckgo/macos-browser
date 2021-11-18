//
//  BookmarksExporter.swift
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

struct BookmarksExporter {

    let list: BookmarkList

    func exportBookmarksTo(url: URL) throws {
        var content = [Template.header]
        content.append(contentsOf: export(list.topLevelEntities))
        content.append(Template.footer)
        try content.joined().write(to: url, atomically: true, encoding: .utf8)
    }

    func export(_ entities: [BaseBookmarkEntity]) -> [String] {
        var content = [String]()
        for entity in entities {
            if let bookmark = entity as? Bookmark {
                content.append(Template.bookmark(title: bookmark.title.escapedForHTML, url: bookmark.url, isFavorite: bookmark.isFavorite))
            }

            if let folder = entity as? BookmarkFolder {
                content.append(Template.openFolder(named: folder.title))
                content.append(contentsOf: export(folder.children))
                content.append(Template.closeFolder)
            }
        }
        return content
    }

}

// MARK: Exported Bookmarks Template

extension BookmarksExporter {

    struct Template {

        static var header = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
            <HTML xmlns:duckduckgo="https://duckduckgo.com/bookmarks">
            <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
            <Title>\(UserText.exportBookmarksFileNameSuffix)</Title>
            <H1>\(UserText.exportBookmarksFileNameSuffix)</H1>
        """

        static let footer = """
        </HTML>
        """

        static func bookmark(title: String, url: URL, isFavorite: Bool = false) -> String {
            """
            <DT><A HREF="\(url.absoluteString)"\(isFavorite ? " duckduckgo:favorite=\"true\"" : "")>\(title)</A>
            """
        }

        static func openFolder(named name: String) -> String {
            """
            <DT><H3 FOLDED>\(name)</H3>
            <DL><p>
            """
        }

        // This "open paragraph" to close the folder is part of the format 🙄
        static var closeFolder = """
            </DL><p>
        """

    }

}

fileprivate extension String {

    var escapedForHTML: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

}
