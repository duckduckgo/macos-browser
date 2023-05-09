//
//  SafariBookmarksReader.swift
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

import Common
import Foundation

final class SafariBookmarksReader {

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
    }

    private let safariBookmarksFileURL: URL

    init(safariBookmarksFileURL: URL) {
        self.safariBookmarksFileURL = safariBookmarksFileURL
    }

    func readBookmarks() -> Result<ImportedBookmarks, SafariBookmarksReader.ImportError> {
        guard let plistData = readPropertyList() else {
            return .failure(.unexpectedBookmarksFileFormat)
        }

        guard let topLevelEntries = plistData[Constants.bookmarkChildrenKey] as? [[String: AnyObject]] else {
            return .failure(.unexpectedBookmarksFileFormat)
        }

        var bookmarksBar: ImportedBookmarks.BookmarkOrFolder?
        var otherBookmarks: [ImportedBookmarks.BookmarkOrFolder] = []

        for entry in topLevelEntries
            where ((entry[Constants.typeKey] as? String) == Constants.listType) || ((entry[Constants.typeKey] as? String) == Constants.leafType) {

            if let title = entry[Constants.titleKey] as? String, title == Constants.readingListKey {
                continue
            }

            if let title = entry[Constants.titleKey] as? String, title == Constants.bookmarksBar {
                bookmarksBar = bookmarkOrFolder(from: entry)
            } else {
                if let otherBookmarkOrFolder = bookmarkOrFolder(from: entry) {
                    otherBookmarks.append(otherBookmarkOrFolder)
                }
            }

        }

        let otherBookmarksFolder = ImportedBookmarks.BookmarkOrFolder(name: "other", type: "folder", urlString: nil, children: otherBookmarks)
        let emptyFolder = ImportedBookmarks.BookmarkOrFolder(name: "bar", type: "folder", urlString: nil, children: [])

        let topLevelFolder = ImportedBookmarks.TopLevelFolders(bookmarkBar: bookmarksBar ?? emptyFolder, otherBookmarks: otherBookmarksFolder)
        let importedBookmarks = ImportedBookmarks(topLevelFolders: topLevelFolder)

        return .success(importedBookmarks)
    }

    private func bookmarkOrFolder(from entry: [String: AnyObject]) -> ImportedBookmarks.BookmarkOrFolder? {
        let possibleTopLevelTitle = (entry[Constants.titleKey] as? String)
        let possibleURIDictionary = entry[Constants.uriDictionaryKey] as? [String: AnyObject]
        let possibleSecondLevelTitle = possibleURIDictionary?[Constants.uriDictionaryTitleKey] as? String

        guard let title = possibleTopLevelTitle ?? possibleSecondLevelTitle else {
            return nil
        }

        if let children = entry[Constants.bookmarkChildrenKey] as? [[String: AnyObject]] {
            assert(entry[Constants.typeKey] as? String == Constants.listType)

            let children = children.compactMap { bookmarkOrFolder(from: $0) }
            return ImportedBookmarks.BookmarkOrFolder(name: title, type: "folder", urlString: nil, children: children)
        } else if let url = entry[Constants.urlStringKey] as? String {
            assert(entry[Constants.typeKey] as? String == Constants.leafType)

            return ImportedBookmarks.BookmarkOrFolder(name: title, type: "bookmark", urlString: url, children: nil)
        }

        return nil
    }

    private func readPropertyList() -> [String: AnyObject]? {
        var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
        var plistData: [String: AnyObject] = [:]

        do {
            let serializedData = try Data(contentsOf: safariBookmarksFileURL)
            plistData = try PropertyListSerialization.propertyList(from: serializedData,
                                                                   options: [],
                                                                   format: &propertyListFormat) as? [String: AnyObject] ?? [:]
        } catch {
            os_log("Failed to read Safari Bookmarks Plist at path: %s", log: .dataImportExport, type: .error, safariBookmarksFileURL.absoluteString)
            return nil
        }

        return plistData
    }

}
