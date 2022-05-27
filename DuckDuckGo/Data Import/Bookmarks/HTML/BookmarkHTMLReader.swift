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

            var isSafariFormat: Bool = false
            var bookmarksBarTitle: String?

            // 3.
            cursor = cursor?.nextSibling
            switch cursor?.htmlTag {
            case .dl:
                try proceedToH3(&cursor)
                bookmarksBarTitle = cursor?.text
            case .h3:
                isSafariFormat = true
                bookmarksBarTitle = cursor?.text
            default:
                throw ImportError.unexpectedBookmarksFileFormat
            }

            guard let bookmarksBarTitle = bookmarksBarTitle else {
                throw ImportError.unexpectedBookmarksFileFormat
            }

            // 4.
            cursor = cursor?.nextSibling
            guard cursor?.htmlTag == .dl else {
                throw ImportError.unexpectedBookmarksFileFormat
            }

            // 5.
            let bookmarkBar = try readFolder(cursor, title: bookmarksBarTitle)

            // 6.
            var other = [ImportedBookmarks.BookmarkOrFolder]()
            while cursor != nil {
                if let folder = try findNextFolder(&cursor, isSafariFormat: isSafariFormat) {
                    other.append(folder)
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

    private func readFolder(_ node: XMLNode?, title: String) throws -> ImportedBookmarks.BookmarkOrFolder {
        var cursor = node?.child(at: 0)

        var children = [ImportedBookmarks.BookmarkOrFolder]()

        while cursor != nil {
            switch cursor?.htmlTag {
            case .dd:
                // 5.1.
                let child = cursor?.child(at: 0)
                if child?.htmlTag == .h3, let title = child?.text {
                    let subFolderNode = child?.nextSibling
                    guard subFolderNode?.htmlTag == .dl else {
                        throw ImportError.unexpectedBookmarksFileFormat
                    }
                    children.append(try readFolder(subFolderNode, title: title))
                }
            case .dt:
                let child = cursor?.child(at: 0)
                guard child?.htmlTag == .a, let name = child?.text else {
                    throw ImportError.unexpectedBookmarksFileFormat
                }
                let childElement = child as? XMLElement
                children.append(.init(
                    name: name,
                    type: "bookmark",
                    urlString: childElement?.attribute(forName: "href")?.stringValue,
                    children: nil
                ))

            default:
                break
            }

            cursor = cursor?.nextSibling
        }
        return .init(name: title, type: "folder", urlString: nil, children: children)
    }

    private func findNextFolder(_ cursor: inout XMLNode?, isSafariFormat: Bool) throws -> ImportedBookmarks.BookmarkOrFolder? {
        if isSafariFormat {
            while cursor != nil {
                cursor = cursor?.nextSibling
                if cursor?.htmlTag == .h3 {
                    break
                }
            }
        } else {
            cursor = cursor?.parent?.nextSibling
            while cursor != nil {
                guard cursor?.htmlTag == .dd else {
                    throw ImportError.unexpectedBookmarksFileFormat
                }
                let firstChild = cursor?.child(at: 0)
                if firstChild?.htmlTag == .h3 {
                    cursor = firstChild
                    break
                }
                cursor = cursor?.nextSibling
            }
        }

        guard cursor != nil else {
            return nil
        }

        let title = cursor?.text ?? ""
        cursor = cursor?.nextSibling
        guard cursor?.htmlTag == .dl else {
            throw ImportError.unexpectedBookmarksFileFormat
        }

        return try readFolder(cursor, title: title)
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
