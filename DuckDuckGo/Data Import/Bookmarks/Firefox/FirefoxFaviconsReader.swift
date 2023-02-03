//
//  FirefoxFaviconsReader.swift
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

final class FirefoxFaviconsReader {

    enum Constants {
        static let faviconsDatabaseName = "favicons.sqlite"
    }

    enum ImportError: Error {
        case noFaviconsDatabaseFound
        case failedToTemporarilyCopyFile
        case unexpectedFaviconsDatabaseFormat
    }

    final class FirefoxFavicon: FetchableRecord {
        let pageURL: String
        let iconURL: String
        let size: Int
        let imageData: Data

        var image: NSImage? {
            NSImage(data: imageData)
        }

        init(row: Row) {
            pageURL = row["page_url"]
            iconURL = row["icon_url"]
            size = row["width"]
            imageData = row["data"]
        }
    }

    private let firefoxFaviconsDatabaseURL: URL

    init(firefoxDataDirectoryURL: URL) {
        self.firefoxFaviconsDatabaseURL = firefoxDataDirectoryURL.appendingPathComponent(Constants.faviconsDatabaseName)
    }

    func readFavicons() -> Result<[String: [FirefoxFavicon]], FirefoxFaviconsReader.ImportError> {
        do {
            return try firefoxFaviconsDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readFavicons(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readFavicons(fromDatabaseURL databaseURL: URL) -> Result<[String: [FirefoxFavicon]], FirefoxFaviconsReader.ImportError> {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)

            let favicons: [FirefoxFavicon] = try queue.read { database in
                guard let favicons = try? FirefoxFavicon.fetchAll(database, sql: allFaviconsQuery()) else {
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
            moz_pages_w_icons.page_url, moz_icons.icon_url, moz_icons.width, moz_icons.data
        FROM
            moz_pages_w_icons
        JOIN
            moz_icons_to_pages ON moz_pages_w_icons.id = moz_icons_to_pages.page_id
        JOIN
            moz_icons ON moz_icons.id = moz_icons_to_pages.icon_id;
        """
    }

}
