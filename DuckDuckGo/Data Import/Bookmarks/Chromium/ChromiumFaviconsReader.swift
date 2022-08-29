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

    enum ImportError: Error {
        case noFaviconsDatabaseFound
        case failedToTemporarilyCopyFile
        case unexpectedFaviconsDatabaseFormat
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

    init(chromiumDataDirectoryURL: URL) {
        self.chromiumFaviconsDatabaseURL = chromiumDataDirectoryURL.appendingPathComponent(Constants.faviconsDatabaseName)
    }

    func readFavicons() -> Result<[String: [ChromiumFavicon]], ChromiumFaviconsReader.ImportError> {
        do {
            return try chromiumFaviconsDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readFavicons(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readFavicons(fromDatabaseURL databaseURL: URL) -> Result<[String: [ChromiumFavicon]], ChromiumFaviconsReader.ImportError> {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)

            let favicons: [ChromiumFavicon] = try queue.read { database in
                guard let favicons = try? ChromiumFavicon.fetchAll(database, sql: allFaviconsQuery()) else {
                    throw ImportError.unexpectedFaviconsDatabaseFormat
                }
                
                return favicons
            }
            
            let faviconsByURL = Dictionary(grouping: favicons, by: { $0.pageURL })
            
            return .success(faviconsByURL)
        } catch {
            return .failure(.unexpectedFaviconsDatabaseFormat)
        }
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

