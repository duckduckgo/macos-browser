//
//  ChromiumFaviconsReader.swift
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
import GRDB

final class ChromiumFaviconsReader {

    enum Constants {
        static let faviconsDatabaseName = "Favicons"
    }

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case copyTemporaryFile
            case dbOpen
            case fetchAllFavicons
        }

        var action: DataImportAction { .favicons }
        let source: DataImport.Source
        let type: OperationType
        let underlyingError: Error?
    }
    func importError(type: ImportError.OperationType, underlyingError: Error) -> ImportError {
        ImportError(source: source, type: type, underlyingError: underlyingError)
    }

    final class ChromiumFavicon: FetchableRecord {
        let pageURL: String
        let iconURL: String
        let size: Int
        let imageData: Data

        var image: NSImage? {
            NSImage(data: imageData)
        }

        init(row: Row) {
            pageURL = row["page_url"]
            iconURL = row["url"]
            size = row["width"]
            imageData = row["image_data"]
        }
    }

    private let chromiumFaviconsDatabaseURL: URL
    private var currentOperationType: ImportError.OperationType = .copyTemporaryFile
    private let source: DataImport.Source

    init(chromiumDataDirectoryURL: URL, source: DataImport.Source) {
        self.chromiumFaviconsDatabaseURL = chromiumDataDirectoryURL.appendingPathComponent(Constants.faviconsDatabaseName)
        self.source = source
    }

    func readFavicons() -> DataImportResult<[String: [ChromiumFavicon]]> {
        do {
            currentOperationType = .copyTemporaryFile
            return try chromiumFaviconsDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                let favicons = try readFavicons(fromDatabaseURL: temporaryDatabaseURL)
                return .success(favicons)
            }
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(importError(type: currentOperationType, underlyingError: error))
        }
    }

    // MARK: - Private

    private func readFavicons(fromDatabaseURL databaseURL: URL) throws -> [String: [ChromiumFavicon]] {
        currentOperationType = .dbOpen
        let queue = try DatabaseQueue(path: databaseURL.path)

        currentOperationType = .fetchAllFavicons
        let favicons: [ChromiumFavicon] = try queue.read { database in
            try ChromiumFavicon.fetchAll(database, sql: allFaviconsQuery())
        }

        let faviconsByURL = Dictionary(grouping: favicons, by: { $0.pageURL })

        return faviconsByURL
    }

    // MARK: - Database Queries

    func allFaviconsQuery() -> String {
        return """
        SELECT
            icon_mapping.page_url, favicons.url, favicon_bitmaps.width, favicon_bitmaps.image_data
        FROM
            icon_mapping
        JOIN
            favicons ON favicons.id = icon_mapping.icon_id
        JOIN
            favicon_bitmaps ON favicon_bitmaps.icon_id = icon_mapping.icon_id;
        """
    }

}
