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

struct HTMLImportedBookmarks {
    let isInSafariFormat: Bool
    let bookmarkCount: Int
    let bookmarks: ImportedBookmarks
}

final class BookmarkHTMLReader {

    enum ImportError: Error {
        case unexpectedBookmarksFileFormat
    }

    init(bookmarksFileURL: URL) {
        self.bookmarksFileURL = bookmarksFileURL
    }

    func readBookmarks() -> Result<HTMLImportedBookmarks, ImportError> {
        do {
            bookmarksCount = 0

            guard let document = try? XMLDocument(contentsOf: bookmarksFileURL, options: .documentTidyHTML) else {
                throw ImportError.unexpectedBookmarksFileFormat
            }

            var cursor = try validateHTMLBookmarksDocument(document)
            let isInSafariFormat = try findTopLevelFolderNameNode(&cursor)
            let bookmarkBar = try readFolder(cursor)

            var other = [ImportedBookmarks.BookmarkOrFolder]()

            while cursor != nil {
                let itemType: XMLNode.BookmarkItemType?
                if isInSafariFormat {
                    itemType = findNextItemInSafariFormat(&cursor)
                } else {
                    itemType = findNextItem(&cursor)
                }

                guard let itemType = itemType else {
                    break
                }

                let items = try readItem(itemType, at: cursor)
                other.append(contentsOf: items)
            }

            let otherBookmarks = ImportedBookmarks.BookmarkOrFolder(name: "other", type: "folder", urlString: nil, children: other)
            let allBookmarks = ImportedBookmarks(topLevelFolders: .init(bookmarkBar: bookmarkBar, otherBookmarks: otherBookmarks))
            let result = HTMLImportedBookmarks(isInSafariFormat: isInSafariFormat, bookmarkCount: bookmarksCount, bookmarks: allBookmarks)

            return .success(result)

        } catch {
            return .failure(.unexpectedBookmarksFileFormat)
        }
    }

    // MARK: - Private

    private func validateHTMLBookmarksDocument(_ document: XMLDocument) throws -> XMLNode? {
        let root = document.rootElement()
        guard let body = root?.child(at: 1) else {
            throw ImportError.unexpectedBookmarksFileFormat
        }

        let cursor = body.child(at: 0)
        guard cursor?.htmlTag == .h1 else {
            throw ImportError.unexpectedBookmarksFileFormat
        }

        return cursor
    }

    private func findTopLevelFolderNameNode(_ cursor: inout XMLNode?) throws -> Bool {
        var isInSafariFormat = false
        cursor = cursor?.nextSibling

        switch cursor?.htmlTag {
        case .dl:
            try proceedToTopLevelFolderNameNode(&cursor)
        case .h3:
            isInSafariFormat = true
        default:
            throw ImportError.unexpectedBookmarksFileFormat
        }

        return isInSafariFormat
    }

    private func proceedToTopLevelFolderNameNode(_ cursor: inout XMLNode?) throws {
        cursor = cursor?.child(at: 0)
        while cursor != nil {
            guard cursor?.htmlTag == .dd else {
                throw ImportError.unexpectedBookmarksFileFormat
            }
            if cursor?.child(at: 0)?.htmlTag == .h3 {
                cursor = cursor?.child(at: 0)
                return
            }
            cursor = cursor?.nextSibling
        }
    }

    private func findNextItem(_ cursor: inout XMLNode?) -> XMLNode.BookmarkItemType? {
        var itemType: XMLNode.BookmarkItemType?
        cursor = cursor?.parent?.nextSibling

        while cursor != nil && itemType == nil {
            itemType = cursor?.itemType(inSafariFormat: false)
            switch itemType {
            case .some:
                cursor = cursor?.child(at: 0)
            case .none:
                cursor = cursor?.nextSibling
            }
        }

        return itemType
    }

    private func findNextItemInSafariFormat(_ cursor: inout XMLNode?) -> XMLNode.BookmarkItemType? {
        var itemType: XMLNode.BookmarkItemType?

        while cursor != nil && itemType == nil {
            cursor = cursor?.nextSibling
            itemType = cursor?.itemType(inSafariFormat: true)
        }

        return itemType
    }

    private func readItem(_ item: XMLNode.BookmarkItemType, at cursor: XMLNode?) throws -> [ImportedBookmarks.BookmarkOrFolder] {
        switch item {
        case .bookmark:
            return [try readBookmark(cursor)]
        case .folder:
            return [try readFolder(cursor)]
        case .safariTopLevelBookmarks:
            return try readFolderContents(cursor)
        }
    }

    private func readFolder(_ node: XMLNode?) throws -> ImportedBookmarks.BookmarkOrFolder {
        var cursor = node

        let title = cursor?.text ?? ""
        cursor = cursor?.nextSibling
        guard cursor?.htmlTag == .dl else {
            throw ImportError.unexpectedBookmarksFileFormat
        }

        let children = try readFolderContents(cursor)
        return .init(name: title, type: "folder", urlString: nil, children: children)
    }

    private func readFolderContents(_ node: XMLNode?) throws -> [ImportedBookmarks.BookmarkOrFolder] {
        var cursor = node
        cursor = cursor?.child(at: 0)

        var children = [ImportedBookmarks.BookmarkOrFolder]()

        while cursor != nil {
            let firstChild = cursor?.child(at: 0)
            switch (cursor?.htmlTag, firstChild?.htmlTag) {
            case (.dd, .h3):
                // 5.1.
                children.append(try readFolder(firstChild))
            case (.dt, .a):
                children.append(try readBookmark(firstChild))
            default:
                break
            }

            cursor = cursor?.nextSibling
        }

        return children
    }

    private func readBookmark(_ node: XMLNode?) throws -> ImportedBookmarks.BookmarkOrFolder {
        guard let bookmark = node?.bookmark else {
            throw ImportError.unexpectedBookmarksFileFormat
        }

        bookmarksCount += 1

        return bookmark
    }

    private let bookmarksFileURL: URL
    private var bookmarksCount: Int = 0
}

private extension XMLNode {

    enum Const {
        static let idAttributeName = "id"
        static let readingListID = "com.apple.ReadingList"
    }

    enum HTMLTag: String {
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

    enum BookmarkItemType {
        case bookmark, folder, safariTopLevelBookmarks
    }

    func itemType(inSafariFormat isInSafariFormat: Bool) -> BookmarkItemType? {
        if isInSafariFormat {
            switch htmlTag {
            case .h3 where !representsSafariReadingList:
                return .folder
            case .dt:
                return .bookmark
            case .dl where child(at: 0)?.child(at: 0)?.htmlTag == .a:
                return .safariTopLevelBookmarks
            default:
                return nil
            }
        } else {
            switch (htmlTag, child(at: 0)?.htmlTag) {
            case (.dd, .h3):
                return .folder
            case (.dt, .a):
                return .bookmark
            default:
                return nil
            }
        }
    }

    var representsSafariReadingList: Bool {
        let xmlElement = self as? XMLElement
        return xmlElement?.attribute(forName: Const.idAttributeName)?.stringValue == Const.readingListID
    }

    var text: String? {
        stringValue?.trimmingWhitespaces()
    }

    var bookmark: ImportedBookmarks.BookmarkOrFolder? {
        guard htmlTag == .a, let name = text else {
            return nil
        }

        return .init(
            name: name,
            type: "bookmark",
            urlString: (self as? XMLElement)?.attribute(forName: "href")?.stringValue,
            children: nil
        )
    }
}
