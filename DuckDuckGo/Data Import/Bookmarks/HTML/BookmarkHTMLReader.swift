//
//  BookmarkHTMLReader.swift
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

final class BookmarkHTMLReader {

    enum ImportError: Error {
        case unexpectedBookmarksFileFormat
    }

    private enum Constants {
        static let bookmarkChildrenKey = "Children"
        static let bookmarksBar = "BookmarksBar"

        static let titleKey = "Title"
        static let urlStringKey = "URLString"
        static let uriDictionaryKey = "URIDictionary"
        static let uriDictionaryTitleKey = "title"
        static let readingListKey = "com.apple.ReadingList"

        static let typeKey = "WebBookmarkType"
        static let listType = "WebBookmarkTypeList"
        static let leafType = "WebBookmarkTypeLeaf"

        static let title = "Bookmarks"
    }

    private let bookmarksFileURL: URL
    private(set) var isSafariFormat: Bool = false
    private(set) var bookmarksCount: Int = 0

    init(bookmarksFileURL: URL) {
        self.bookmarksFileURL = bookmarksFileURL
    }

    func readBookmarks() -> Result<ImportedBookmarks, ImportError> {
        do {
            guard let document = try? XMLDocument(contentsOf: bookmarksFileURL, options: .documentTidyHTML) else {
                throw ImportError.unexpectedBookmarksFileFormat
            }

            // 1.
            let root = document.rootElement()
            guard let body = root?.child(at: 1) else {
                throw ImportError.unexpectedBookmarksFileFormat
            }

            // 2.
            var cursor = body.child(at: 0)
            guard cursor?.htmlTag == .h1 else {
                throw ImportError.unexpectedBookmarksFileFormat
            }

            // 3.
            cursor = cursor?.nextSibling
            switch cursor?.htmlTag {
            case .dl:
                try proceedToH3(&cursor)
            case .h3:
                isSafariFormat = true
            default:
                throw ImportError.unexpectedBookmarksFileFormat
            }

            // 5.
            let bookmarkBar = try readFolder(cursor)

            // 6.
            var other = [ImportedBookmarks.BookmarkOrFolder]()
            while cursor != nil {
                if let item = try findNextItem(&cursor) {
                    other.append(item)
                }
            }

            let otherBookmarks = ImportedBookmarks.BookmarkOrFolder(name: "other", type: "folder", urlString: nil, children: other)

            return .success(.init(topLevelFolders: .init(bookmarkBar: bookmarkBar, otherBookmarks: otherBookmarks)))

        } catch {
            return .failure(.unexpectedBookmarksFileFormat)
        }
    }

    // MARK: - Private

    private func proceedToH3(_ cursor: inout XMLNode?) throws {
        cursor = cursor?.child(at: 0)
        while cursor != nil {
            guard case .dd = cursor?.htmlTag else {
                throw ImportError.unexpectedBookmarksFileFormat
            }
            if cursor?.child(at: 0)?.htmlTag == .h3 {
                cursor = cursor?.child(at: 0)
                return
            }
            cursor = cursor?.nextSibling
        }
    }

    private func readFolder(_ node: XMLNode?) throws -> ImportedBookmarks.BookmarkOrFolder {
        var cursor = node

        let title = cursor?.text ?? ""
        cursor = cursor?.nextSibling
        guard cursor?.htmlTag == .dl else {
            throw ImportError.unexpectedBookmarksFileFormat
        }

        cursor = cursor?.child(at: 0)

        var children = [ImportedBookmarks.BookmarkOrFolder]()

        while cursor != nil {
            let firstChild = cursor?.child(at: 0)
            switch (cursor?.htmlTag, firstChild?.htmlTag) {
            case (.dd, .h3):
                // 5.1.
                children.append(try readFolder(firstChild))
            case (.dt, .a):
                children.append(try readItem(firstChild))
            default:
                break
            }

            cursor = cursor?.nextSibling
        }
        return .init(name: title, type: "folder", urlString: nil, children: children)
    }

    private func readItem(_ node: XMLNode?) throws -> ImportedBookmarks.BookmarkOrFolder {
        guard node?.htmlTag == .a, let name = node?.text else {
            throw ImportError.unexpectedBookmarksFileFormat
        }
        let xmlElement = node as? XMLElement

        bookmarksCount += 1

        return .init(
            name: name,
            type: "bookmark",
            urlString: xmlElement?.attribute(forName: "href")?.stringValue,
            children: nil
        )
    }

    private func findNextItem(_ cursor: inout XMLNode?) throws -> ImportedBookmarks.BookmarkOrFolder? {

        var isFolder: Bool?

        if isSafariFormat {
            while cursor != nil && isFolder == nil {
                cursor = cursor?.nextSibling
                switch cursor?.htmlTag {
                case .h3:
                    isFolder = true
                case .dt:
                    isFolder = false
                default:
                    break
                }
            }
        } else {
            cursor = cursor?.parent?.nextSibling
            while cursor != nil && isFolder == nil {
                let firstChild = cursor?.child(at: 0)
                switch (cursor?.htmlTag, firstChild?.htmlTag) {
                case (.dd, .h3):
                    cursor = firstChild
                    isFolder = true
                case (.dt, .a):
                    cursor = firstChild
                    isFolder = false
                default:
                    cursor = cursor?.nextSibling
                }
            }
        }

        switch isFolder {
        case true:
            return try readFolder(cursor)
        case false:
            return try readItem(cursor)
        default:
            return nil
        }
    }
}

private extension XMLNode {

    enum HTMLTag: String, CaseIterable {
        case h1
        case h3
        case dl
        case dt
        case dd
        case a
    }

    var htmlTag: HTMLTag? {
        guard let name = name else {
            return nil
        }
        return .init(rawValue: name)
    }

    var text: String? {
        stringValue?.trimmingWhitespaces()
    }
}
