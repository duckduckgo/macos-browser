//
//  FirefoxBookmarksReader.swift
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
import GRDB

final class FirefoxBookmarksReader {

    enum Constants {
        static let placesDatabaseName = "places.sqlite"
    }

    enum ImportError: Error {
        case noBookmarksFileFound
        case failedToTemporarilyCopyFile
        case unexpectedBookmarksDatabaseFormat
    }

    private let firefoxPlacesDatabaseURL: URL

    init(firefoxDataDirectoryURL: URL) {
        self.firefoxPlacesDatabaseURL = firefoxDataDirectoryURL.appendingPathComponent(Constants.placesDatabaseName)
    }

    func readBookmarks() -> Result<ImportedBookmarks, FirefoxBookmarksReader.ImportError> {
        do {
            return try firefoxPlacesDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readBookmarks(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readBookmarks(fromDatabaseURL databaseURL: URL) -> Result<ImportedBookmarks, FirefoxBookmarksReader.ImportError> {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)

            let bookmarks: DatabaseBookmarks = try queue.read { database in
                guard let rootEntries = try? FolderRow.fetchAll(database, sql: rootEntryQuery()), let rootEntry = rootEntries.first else {
                    throw ImportError.unexpectedBookmarksDatabaseFormat
                }

                assert(rootEntries.count == 1, "moz_bookmarks should only have one root entry")

                let topLevelFolders = try FolderRow.fetchAll(database, sql: foldersWithParentQuery(), arguments: [rootEntry.id])
                let tagsFolder = topLevelFolders.first { $0.title == "tags" }

                let allBookmarks = try BookmarkRow.fetchAll(database, sql: allBookmarksQuery())
                let allFolders = try FolderRow.fetchAll(database, sql: allFoldersQuery(), arguments: [tagsFolder?.id ?? 0])

                let foldersByParent: [Int: [FolderRow]] = allFolders.reduce(into: [:]) { result, folder in
                    var children: [FolderRow] = result[folder.parent] ?? []
                    children.append(folder)

                    result[folder.parent] = children
                }

                let bookmarksByFolder: [Int: [BookmarkRow]] = allBookmarks.reduce(into: [:]) { result, bookmark in
                    var children: [BookmarkRow] = result[bookmark.parent] ?? []
                    children.append(bookmark)

                    result[bookmark.parent] = children
                }

                return DatabaseBookmarks(topLevelFolders: topLevelFolders, foldersByParent: foldersByParent, bookmarksByFolder: bookmarksByFolder)
            }

            let importedBookmarks = mapDatabaseBookmarksToImportedBookmarks(bookmarks)
            return .success(importedBookmarks)
        } catch {
            return .failure(.unexpectedBookmarksDatabaseFormat)
        }
    }
    
    fileprivate class DatabaseBookmarks {
        let topLevelFolders: [FolderRow]
        let foldersByParent: [Int: [FolderRow]]
        let bookmarksByFolder: [Int: [BookmarkRow]]

        init(topLevelFolders: [FirefoxBookmarksReader.FolderRow],
             foldersByParent: [Int: [FirefoxBookmarksReader.FolderRow]],
             bookmarksByFolder: [Int: [FirefoxBookmarksReader.BookmarkRow]]) {
            self.topLevelFolders = topLevelFolders
            self.foldersByParent = foldersByParent
            self.bookmarksByFolder = bookmarksByFolder
        }
    }

    fileprivate struct FolderRow: FetchableRecord {
        let id: Int
        let title: String
        let parent: Int

        init(row: Row) {
            id = row["id"]
            title = row["title"]
            parent = row["parent"]
        }
    }

    fileprivate struct BookmarkRow: FetchableRecord {
        let id: Int
        let title: String?
        let url: String
        let parent: Int

        init(row: Row) {
            id = row["id"]
            title = row["title"]
            url = row["url"]
            parent = row["parent"]
        }
    }

    private func mapDatabaseBookmarksToImportedBookmarks(_ databaseBookmarks: DatabaseBookmarks) -> ImportedBookmarks {
        let menu = databaseBookmarks.topLevelFolders.first(where: { $0.title == "menu" })
        let toolbar = databaseBookmarks.topLevelFolders.first(where: { $0.title == "toolbar" })
        let unfiled = databaseBookmarks.topLevelFolders.first(where: { $0.title == "unfiled" })

        let menuBookmarksAndFolders = children(parentID: menu?.id, bookmarks: databaseBookmarks)
        let toolbarBookmarksAndFolders = children(parentID: toolbar?.id, bookmarks: databaseBookmarks)
        let unfiledBookmarksAndFolders = children(parentID: unfiled?.id, bookmarks: databaseBookmarks)

        let toolbarFolder = ImportedBookmarks.BookmarkOrFolder(name: "bar",
                                                               type: "folder",
                                                               urlString: nil,
                                                               children: toolbarBookmarksAndFolders + menuBookmarksAndFolders)

        let unfiledFolder = ImportedBookmarks.BookmarkOrFolder(name: "other", type: "folder", urlString: nil, children: unfiledBookmarksAndFolders)
        let folders = ImportedBookmarks.TopLevelFolders(bookmarkBar: toolbarFolder, otherBookmarks: unfiledFolder)
        
        return ImportedBookmarks(topLevelFolders: folders)
    }

    private func children(parentID: Int?, bookmarks: DatabaseBookmarks) -> [ImportedBookmarks.BookmarkOrFolder] {
        guard let parentID = parentID else {
            return []
        }

        let childFolders = bookmarks.foldersByParent[parentID] ?? []
        let childBookmarks = bookmarks.bookmarksByFolder[parentID] ?? []

        var bookmarksAndFolders = [ImportedBookmarks.BookmarkOrFolder]()

        for childFolder in childFolders {
            let recursiveChildren = children(parentID: childFolder.id, bookmarks: bookmarks)
            let folder = ImportedBookmarks.BookmarkOrFolder.from(folderRow: childFolder, children: recursiveChildren)
            bookmarksAndFolders.append(folder)
        }

        bookmarksAndFolders.append(contentsOf: childBookmarks.map(ImportedBookmarks.BookmarkOrFolder.from(bookmarkRow:)))

        return bookmarksAndFolders
    }

    // MARK: - Database Queries

    func rootEntryQuery() -> String {
        return "SELECT id,type,title,parent FROM moz_bookmarks WHERE guid = 'root________';"
    }

    func foldersWithParentQuery() -> String {
        return "SELECT id,type,title,parent FROM moz_bookmarks WHERE parent = ?;"
    }

    func allBookmarksQuery() -> String {
        return """
        SELECT
            moz_places.id,
            moz_bookmarks.title,
            moz_places.url,
            moz_bookmarks.parent
        FROM
            moz_bookmarks
        LEFT JOIN
            moz_places
        ON
            moz_bookmarks.fk = moz_places.id
        WHERE
            moz_bookmarks.type = 1
        ;
        """
    }

    func allFoldersQuery() -> String {
        return """
        SELECT
            id,
            title,
            parent
        FROM
            moz_bookmarks
        WHERE
            type = 2
        AND
            title IS NOT NULL
        AND
            -- Ignore the root folder
            id IS NOT 1
        AND
            -- Allow the caller to filter out tags; they are given the same type as folders, so supply the tag folder ID for this value to ignore them
            parent != ?
        ;
        """
    }

}

extension ImportedBookmarks.BookmarkOrFolder {

    fileprivate static func from(folderRow: FirefoxBookmarksReader.FolderRow,
                                 children: [ImportedBookmarks.BookmarkOrFolder]) -> ImportedBookmarks.BookmarkOrFolder {
        return ImportedBookmarks.BookmarkOrFolder(name: folderRow.title, type: "folder", urlString: nil, children: children)
    }

    fileprivate static func from(bookmarkRow: FirefoxBookmarksReader.BookmarkRow) -> ImportedBookmarks.BookmarkOrFolder {
        return ImportedBookmarks.BookmarkOrFolder(name: bookmarkRow.title ?? "", type: "bookmark", urlString: bookmarkRow.url, children: nil)
    }

}
