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
import BrowserServicesKit

final class FirefoxBookmarksReader {

    enum Constants {
        static let placesDatabaseName = "places.sqlite"
    }

    private enum BookmarkGUID {
        static let root = "root________"
        static let menu = "menu________"
        static let toolbar = "toolbar_____"
        static let tags = "tags________"
        static let unfiled = "unfiled_____"
        static let mobile = "mobile______"
    }

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case dbOpen

            case fetchRootEntries
            case noRootEntries
            case fetchTopLevelFolders
            case fetchAllBookmarks
            case fetchAllFolders

            case copyTemporaryFile

            case couldNotFindBookmarksFile
        }

        var action: DataImportAction { .bookmarks }
        let type: OperationType
        let underlyingError: Error?

        var errorType: DataImport.ErrorType {
            switch type {
            case .dbOpen, .couldNotFindBookmarksFile: .noData
            case .fetchRootEntries, .noRootEntries, .fetchTopLevelFolders, .fetchAllBookmarks, .fetchAllFolders: .dataCorrupted
            case .copyTemporaryFile: .other
            }
        }
    }

    private let firefoxPlacesDatabaseURL: URL
    private var currentOperationType: ImportError.OperationType = .copyTemporaryFile
    private let otherBookmarksFolderTitle: String
    private let mobileBookmarksFolderTitle: String

    init(firefoxDataDirectoryURL: URL, otherBookmarksFolderTitle: String = UserText.otherBookmarksImportedFolderTitle, mobileBookmarksFolderTitle: String = UserText.mobileBookmarksImportedFolderTitle) {
        self.firefoxPlacesDatabaseURL = firefoxDataDirectoryURL.appendingPathComponent(Constants.placesDatabaseName)
        self.otherBookmarksFolderTitle = otherBookmarksFolderTitle
        self.mobileBookmarksFolderTitle = mobileBookmarksFolderTitle
    }

    func readBookmarks() -> DataImportResult<ImportedBookmarks> {
        guard FileManager.default.fileExists(atPath: firefoxPlacesDatabaseURL.path) else {
            return .failure(ImportError(type: .couldNotFindBookmarksFile, underlyingError: nil))
        }

        do {
            currentOperationType = .copyTemporaryFile
            return try firefoxPlacesDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                let bookmarks = try readBookmarks(fromDatabaseURL: temporaryDatabaseURL)
                return .success(bookmarks)
            }
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(ImportError(type: currentOperationType, underlyingError: error))
        }
    }

    // MARK: - Private

    private func readBookmarks(fromDatabaseURL databaseURL: URL) throws -> ImportedBookmarks {
        currentOperationType = .dbOpen
        let queue = try DatabaseQueue(path: databaseURL.path)

        let bookmarks: DatabaseBookmarks = try queue.read { database in
            currentOperationType = .fetchRootEntries
            let rootEntries = try FolderRow.fetchAll(database, sql: rootEntryQuery())
            guard let rootEntry = rootEntries.first else { throw ImportError(type: .noRootEntries, underlyingError: nil) }

            assert(rootEntries.count == 1, "moz_bookmarks should only have one root entry")

            currentOperationType = .fetchTopLevelFolders
            let topLevelFolders = try FolderRow.fetchAll(database, sql: foldersWithParentQuery(), arguments: [rootEntry.id])
            let tagsFolder = topLevelFolders.first { $0.guid == BookmarkGUID.tags }

            currentOperationType = .fetchAllBookmarks
            let allBookmarks = try BookmarkRow.fetchAll(database, sql: allBookmarksQuery())
                    .filter { !($0.url.hasPrefix("place:") || $0.url.hasPrefix("about:")) }

            currentOperationType = .fetchAllFolders
            let allFolders = try FolderRow.fetchAll(database, sql: allFoldersQuery(), arguments: [tagsFolder?.id ?? 0])

            let foldersByParent: [Int: [FolderRow]] = allFolders.reduce(into: [:]) { result, folder in
                result[folder.parent, default: []].append(folder)
            }

            let bookmarksByFolder: [Int: [BookmarkRow]] = allBookmarks.reduce(into: [:]) { result, bookmark in
                result[bookmark.parent, default: []].append(bookmark)
            }

            return DatabaseBookmarks(topLevelFolders: topLevelFolders, foldersByParent: foldersByParent, bookmarksByFolder: bookmarksByFolder)
        }

        let importedBookmarks = mapDatabaseBookmarksToImportedBookmarks(bookmarks)
        return importedBookmarks
    }

    fileprivate struct DatabaseBookmarks {
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
        let guid: String

        init(row: Row) throws {
            id = try row["id"] ?? { throw FetchableRecordError<FolderRow>(column: 0) }()
            title = try row["title"] ?? { throw FetchableRecordError<FolderRow>(column: 1) }()
            parent = try row["parent"] ?? { throw FetchableRecordError<FolderRow>(column: 2) }()
            guid = try row["guid"] ?? { throw FetchableRecordError<FolderRow>(column: 3) }()
        }
    }

    fileprivate struct BookmarkRow: FetchableRecord {
        let id: Int
        let title: String?
        let url: String
        let parent: Int

        init(row: Row) throws {
            id = try row["id"] ?? { throw FetchableRecordError<BookmarkRow>(column: 0) }()
            self.title = row["title"]
            url = try row["url"] ?? { throw FetchableRecordError<BookmarkRow>(column: 2) }()
            parent = try row["parent"] ?? { throw FetchableRecordError<BookmarkRow>(column: 3) }()
        }
    }

    private func mapDatabaseBookmarksToImportedBookmarks(_ databaseBookmarks: DatabaseBookmarks) -> ImportedBookmarks {
        let menu = databaseBookmarks.topLevelFolders.first(where: { $0.guid == BookmarkGUID.menu })
        let toolbar = databaseBookmarks.topLevelFolders.first(where: { $0.guid == BookmarkGUID.toolbar })
        let unfiled = databaseBookmarks.topLevelFolders.first(where: { $0.guid == BookmarkGUID.unfiled })
        let mobile = databaseBookmarks.topLevelFolders.first(where: { $0.guid == BookmarkGUID.mobile })
        let filteredGUIDs = Set([BookmarkGUID.menu, BookmarkGUID.toolbar, BookmarkGUID.unfiled, BookmarkGUID.mobile, BookmarkGUID.tags])
        let otherFolders = databaseBookmarks.topLevelFolders.filter { !filteredGUIDs.contains($0.guid) }

        let menuBookmarksAndFolders = children(parentID: menu?.id, bookmarks: databaseBookmarks)
        let toolbarBookmarksAndFolders = children(parentID: toolbar?.id, bookmarks: databaseBookmarks)
        let syncedBookmarksAndFolders = children(parentID: mobile?.id, bookmarks: databaseBookmarks)
        let unfiledBookmarksAndFolders = children(parentID: unfiled?.id, bookmarks: databaseBookmarks)
            + otherFolders.flatMap { children(parentID: $0.id, bookmarks: databaseBookmarks) }

        let toolbarFolder = ImportedBookmarks.BookmarkOrFolder(name: "bar",
                                                               type: .folder,
                                                               urlString: nil,
                                                               children: toolbarBookmarksAndFolders + menuBookmarksAndFolders)

        let unfiledFolder = ImportedBookmarks.BookmarkOrFolder(name: self.otherBookmarksFolderTitle, type: .folder, urlString: nil, children: unfiledBookmarksAndFolders)
        let syncedFolder = ImportedBookmarks.BookmarkOrFolder(name: self.mobileBookmarksFolderTitle, type: .folder, urlString: nil, children: syncedBookmarksAndFolders)
        let folders = ImportedBookmarks.TopLevelFolders(bookmarkBar: toolbarFolder, otherBookmarks: unfiledFolder, syncedBookmarks: syncedFolder)

        return ImportedBookmarks(topLevelFolders: folders)
    }

    private func children(parentID: Int?, bookmarks: DatabaseBookmarks) -> [ImportedBookmarks.BookmarkOrFolder] {
        guard let parentID else { return [] }

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
        return "SELECT id,type,title,parent,guid FROM moz_bookmarks WHERE guid = '\(BookmarkGUID.root)';"
    }

    func foldersWithParentQuery() -> String {
        return "SELECT id,type,title,parent,guid FROM moz_bookmarks WHERE parent = ?;"
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
        INNER JOIN
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
            parent,
            guid
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
        return ImportedBookmarks.BookmarkOrFolder(name: folderRow.title, type: .folder, urlString: nil, children: children)
    }

    fileprivate static func from(bookmarkRow: FirefoxBookmarksReader.BookmarkRow) -> ImportedBookmarks.BookmarkOrFolder {
        return ImportedBookmarks.BookmarkOrFolder(name: bookmarkRow.title ?? "", type: .bookmark, urlString: bookmarkRow.url, children: nil)
    }

}
