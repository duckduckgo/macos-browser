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

    enum RelevantItem: String, CaseIterable {
        case h1
        case h3
        case dl
        case dt
        case dd
        case a
    }

    private let bookmarksFileURL: URL

    init(bookmarksFileURL: URL) {
        self.bookmarksFileURL = bookmarksFileURL
    }

    private func proceedToH3(_ cursor: inout XMLNode?) throws {
        cursor = cursor?.child(at: 0)
        while cursor != nil {
            guard case .dd = cursor?.relevantItem else {
                throw ImportError.unexpectedBookmarksFileFormat
            }
            if cursor?.child(at: 0)?.relevantItem == .h3 {
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
            switch cursor?.relevantItem {
            case .dd:
                // 5.1.
                let child = cursor?.child(at: 0)
                if child?.relevantItem == .h3, let title = child?.stringValue?.trimmingWhitespaces() {
                    let subFolderNode = child?.nextSibling
                    guard subFolderNode?.relevantItem == .dl else {
                        throw ImportError.unexpectedBookmarksFileFormat
                    }
                    children.append(try readFolder(subFolderNode, title: title))
                }
            case .dt:
                let child = cursor?.child(at: 0)
                guard child?.relevantItem == .a, let name = child?.stringValue?.trimmingWhitespaces() else {
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
                if cursor?.relevantItem == .h3 {
                    break
                }
            }
        } else {
            cursor = cursor?.parent?.nextSibling
            while cursor != nil {
                guard cursor?.relevantItem == .dd else {
                    throw ImportError.unexpectedBookmarksFileFormat
                }
                let firstChild = cursor?.child(at: 0)
                if firstChild?.relevantItem == .h3 {
                    cursor = firstChild
                    break
                }
                cursor = cursor?.nextSibling
            }
        }

        guard cursor != nil else {
            return nil
        }

        let title = cursor?.stringValue?.trimmingWhitespaces() ?? ""
        cursor = cursor?.nextSibling
        guard cursor?.relevantItem == .dl else {
            throw ImportError.unexpectedBookmarksFileFormat
        }

        return try readFolder(cursor, title: title)
    }

    func readBookmarks() -> Result<ImportedBookmarks, ImportError> {
        guard let document = try? XMLDocument(contentsOf: bookmarksFileURL, options: .documentTidyHTML) else {
            return .failure(.unexpectedBookmarksFileFormat)
        }

        var isSafariFormat: Bool = false
        var bookmarksBarTitle: String?

        // 1.
        let root = document.rootElement()
        guard let body = root?.child(at: 1) else {
            return .failure(.unexpectedBookmarksFileFormat)
        }

        // 2.
        var cursor = body.child(at: 0)
        guard cursor?.relevantItem == .h1 else {
            return .failure(.unexpectedBookmarksFileFormat)
        }

        do {
            // 3.
            cursor = cursor?.nextSibling
            switch cursor?.relevantItem {
            case .dl:
                try proceedToH3(&cursor)
                bookmarksBarTitle = cursor?.stringValue?.trimmingWhitespaces()
            case .h3:
                isSafariFormat = true
                bookmarksBarTitle = cursor?.stringValue?.trimmingWhitespaces()
            default:
                throw ImportError.unexpectedBookmarksFileFormat
            }

            guard let bookmarksBarTitle = bookmarksBarTitle else {
                throw ImportError.unexpectedBookmarksFileFormat
            }

            // 4.
            cursor = cursor?.nextSibling
            guard cursor?.relevantItem == .dl else {
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

//        guard let relevantItems = body.children!.filter(\.isRelevant) else {
//            return .failure(.unexpectedBookmarksFileFormat)
//        }

//        var topLevelFolders: ImportedBookmarks.TopLevelFolders
//        var bookmarksBar: ImportedBookmarks.BookmarkOrFolder = .ini

//        var lookFor

//        for i in 0..<relevantItems.count {
//            let item = relevantItems[i]
//
//            switch item.name {
//            case RelevantItem.h1.rawValue:
//                print("h1")
//                guard var nextItem = relevantItems[safe: i + 1] else {
//                    continue
//                }
//                switch nextItem.name {
//                case RelevantItem.dl.rawValue:
//                    break
////                    nextItem = nextItem.children?[safe: 0]
//                case RelevantItem.h3.rawValue:
//                    break
//                default:
//                    break
//                }
//
//            case RelevantItem.dt.rawValue:
//                print("h3")
//            case RelevantItem.dl.rawValue:
//                print("dl")
//            default:
//                break
//            }
//        }
//
//        let favorites = body?.children?[safe: 2]
//        print(root)

        return .failure(.unexpectedBookmarksFileFormat)
    }

    private func readBookmarksFolder(with node: XMLNode) {
        guard let relevantItems = node.children?.filter(\.isRelevant) else {
            return
        }
    }

//        guard let plistData = readPropertyList() else {
//            return .failure(.unexpectedBookmarksFileFormat)
//        }
//
//        guard let topLevelEntries = plistData[Constants.bookmarkChildrenKey] as? [[String: AnyObject]] else {
//            return .failure(.unexpectedBookmarksFileFormat)
//        }
//
//        var bookmarksBar: ImportedBookmarks.BookmarkOrFolder?
//        var otherBookmarks: [ImportedBookmarks.BookmarkOrFolder] = []
//
//        for entry in topLevelEntries
//            where ((entry[Constants.typeKey] as? String) == Constants.listType) || ((entry[Constants.typeKey] as? String) == Constants.leafType) {
//
//            if let title = entry[Constants.titleKey] as? String, title == Constants.readingListKey {
//                continue
//            }
//
//            if let title = entry[Constants.titleKey] as? String, title == Constants.bookmarksBar {
//                bookmarksBar = bookmarkOrFolder(from: entry)
//            } else {
//                if let otherBookmarkOrFolder = bookmarkOrFolder(from: entry) {
//                    otherBookmarks.append(otherBookmarkOrFolder)
//                }
//            }
//
//        }
//
//        let otherBookmarksFolder = ImportedBookmarks.BookmarkOrFolder(name: "other", type: "folder", urlString: nil, children: otherBookmarks)
//        let emptyFolder = ImportedBookmarks.BookmarkOrFolder(name: "bar", type: "folder", urlString: nil, children: [])
//
//        let topLevelFolder = ImportedBookmarks.TopLevelFolders(bookmarkBar: bookmarksBar ?? emptyFolder, otherBookmarks: otherBookmarksFolder)
//        let importedBookmarks = ImportedBookmarks(topLevelFolders: topLevelFolder)
//
//        return .success(importedBookmarks)

}

private extension XMLNode {
    var isRelevant: Bool {
        guard let name = name else {
            return false
        }
        return BookmarkHTMLReader.RelevantItem.allCases.map(\.rawValue).contains(name)
    }

    var relevantItem: BookmarkHTMLReader.RelevantItem? {
        guard let name = name else {
            return nil
        }
        return .init(rawValue: name)
    }
}
