//
//  SafariFaviconsReader.swift
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

final class SafariFaviconsReader {

    enum Constants {
        static let faviconsDatabaseName = "favicons.db"
    }

    enum ImportError: Error {
        case noFaviconsDatabaseFound
        case failedToTemporarilyCopyFile
        case unexpectedFaviconsDatabaseFormat
    }
    
    fileprivate final class SafariFaviconRecord: FetchableRecord {
        let pageURL: String
        let iconURL: String
        let size: Int
        let uuid: String

        init(row: Row) {
            pageURL = row["page_url"]
            iconURL = row["icon_url"]
            size = row["width"]
            uuid = row["uuid"]
        }
    }
    
    final class SafariFavicon {
        let pageURL: String
        let iconURL: String
        let size: Int
        let imageData: Data
        
        var image: NSImage? {
            NSImage(data: imageData)
        }
        
        fileprivate init(faviconRecord: SafariFaviconRecord, imageData: Data) {
            self.pageURL = faviconRecord.pageURL
            self.iconURL = faviconRecord.iconURL
            self.size = faviconRecord.size
            self.imageData = imageData
        }
    }

    private let safariFaviconsDatabaseURL: URL

    init(safariDataDirectoryURL: URL) {
        self.safariFaviconsDatabaseURL = safariDataDirectoryURL
            .appendingPathComponent("Favicon Cache")
            .appendingPathComponent(Constants.faviconsDatabaseName)
    }

    func readFavicons() -> Result<[String: [SafariFavicon]], SafariFaviconsReader.ImportError> {
        do {
            return try safariFaviconsDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readFavicons(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readFavicons(fromDatabaseURL databaseURL: URL) -> Result<[String: [SafariFavicon]], SafariFaviconsReader.ImportError> {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)

            let faviconRecords: [SafariFaviconRecord] = try queue.read { database in
                guard let records = try? SafariFaviconRecord.fetchAll(database, sql: allFaviconsQuery()) else {
                    throw ImportError.unexpectedFaviconsDatabaseFormat
                }
                
                return records
            }
            
            let favicons: [SafariFavicon] = faviconRecords.compactMap { record in
                guard let imageData = fetchImageData(with: record.uuid) else {
                    return nil
                }

                return SafariFavicon(faviconRecord: record, imageData: imageData)
            }

            let faviconsByURL = Dictionary(grouping: favicons, by: { $0.pageURL })
            
            return .success(faviconsByURL)
        } catch {
            return .failure(.unexpectedFaviconsDatabaseFormat)
        }
    }
    
    private func fetchImageData(with uuid: String) -> Data? {
        let cleanedUUID = uuid.replacingOccurrences(of: "-", with: "")
        let faviconsDirectoryURL = safariFaviconsDatabaseURL.deletingLastPathComponent()
        let faviconURL = faviconsDirectoryURL.appendingPathComponent("favicons").appendingPathComponent(cleanedUUID)
        
        return try? Data(contentsOf: faviconURL)
    }

    // MARK: - Database Queries

    func allFaviconsQuery() -> String {
        return """
        SELECT
            page_url.url AS page_url, icon_info.url AS icon_url, icon_info.width, page_url.uuid
        FROM
            page_url
        JOIN
            icon_info ON icon_info.uuid = page_url.uuid
        """
    }

}
