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
import os.log
import BrowserServicesKit

final class SafariBookmarksReader {

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

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case readPlist

            case getTopLevelEntries
            case getChildren
            case entryNotDict
        }

        var action: DataImportAction { .bookmarks }
        let type: OperationType
        let underlyingError: Error?

        var errorType: DataImport.ErrorType {
            switch underlyingError {
            case let error as CocoaError where error.code == .fileReadNoSuchFile: .noData
            default: .dataCorrupted
            }
        }
    }

    private let safariBookmarksFileURL: URL
    private var currentOperationType: ImportError.OperationType = .readPlist
    private let otherBookmarksFolderTitle: String

    init(safariBookmarksFileURL: URL, otherBookmarksFolderTitle: String = UserText.otherBookmarksImportedFolderTitle) {
        self.safariBookmarksFileURL = safariBookmarksFileURL
        self.otherBookmarksFolderTitle = otherBookmarksFolderTitle
    }

    func readBookmarks() -> DataImportResult<ImportedBookmarks> {
        do {
            let bookmarks = try reallyReadBookmarks()
            return .success(bookmarks)
        } catch {
            Logger.dataImportExport.error("Failed to read Safari Bookmarks Plist at \(self.safariBookmarksFileURL.path): \(error.localizedDescription)")
            switch error {
            case let error as ImportError:
                return .failure(error)
            default:
                return .failure(ImportError(type: currentOperationType, underlyingError: error))
            }
        }
    }

    func validateFileReadAccess() -> DataImportResult<Void> {
        if !FileManager.default.isReadableFile(atPath: safariBookmarksFileURL.path) {
            do {
                try _=Data(contentsOf: safariBookmarksFileURL)
            } catch {
                return .failure(ImportError(type: .readPlist, underlyingError: error))
            }
        }
        return .success( () )
    }

    private func reallyReadBookmarks() throws -> ImportedBookmarks {
        currentOperationType = .readPlist
        let plistData = try readPropertyList()

        guard let children = plistData[Constants.bookmarkChildrenKey] else { throw ImportError(type: .getChildren, underlyingError: nil) }
        guard let topLevelEntries = children as? [Any] else { throw ImportError(type: .getTopLevelEntries, underlyingError: nil) }

        var bookmarksBar: ImportedBookmarks.BookmarkOrFolder?
        var otherBookmarks: [ImportedBookmarks.BookmarkOrFolder] = []

        for entry in topLevelEntries {
            guard let entry = entry as? [String: AnyObject] else { throw ImportError(type: .entryNotDict, underlyingError: nil) }
            guard (entry[Constants.typeKey] as? String) == Constants.listType || (entry[Constants.typeKey] as? String) == Constants.leafType else { continue }

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

        let otherBookmarksFolder = ImportedBookmarks.BookmarkOrFolder(name: self.otherBookmarksFolderTitle, type: .folder, urlString: nil, children: otherBookmarks)
        let emptyFolder = ImportedBookmarks.BookmarkOrFolder(name: "bar", type: .folder, urlString: nil, children: [])

        let topLevelFolder = ImportedBookmarks.TopLevelFolders(bookmarkBar: bookmarksBar ?? emptyFolder, otherBookmarks: otherBookmarksFolder, syncedBookmarks: nil)
        let importedBookmarks = ImportedBookmarks(topLevelFolders: topLevelFolder)

        return importedBookmarks
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
            return ImportedBookmarks.BookmarkOrFolder(name: title, type: .folder, urlString: nil, children: children)
        } else if let url = entry[Constants.urlStringKey] as? String {
            assert(entry[Constants.typeKey] as? String == Constants.leafType)

            return ImportedBookmarks.BookmarkOrFolder(name: title, type: .bookmark, urlString: url, children: nil)
        }

        return nil
    }

    private func readPropertyList() throws -> [String: AnyObject] {
        var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
        var plistData: [String: AnyObject] = [:]

        let serializedData = try Data(contentsOf: safariBookmarksFileURL)
        plistData = try PropertyListSerialization.propertyList(from: serializedData,
                                                               options: [],
                                                               format: &propertyListFormat) as? [String: AnyObject] ?? [:]

        return plistData
    }

}
