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
import CryptoKit
import GRDB

final class SafariFaviconsReader {

    enum Constants {
        static let faviconsDatabaseName = "TouchIconCacheSettings.db"
    }

    enum ImportError: Error {
        case noFaviconsDatabaseFound
        case failedToTemporarilyCopyFile
        case unexpectedFaviconsDatabaseFormat
    }
    
    fileprivate final class SafariFaviconRecord: FetchableRecord {
        let host: String
        
        var formattedHost: String? {
            guard let url = URL(string: host) else {
                return nil
            }
            
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                return nil
            }

            components.scheme = "https"
            components.host = components.path
            components.path = ""
            
            return components.string
        }

        init(row: Row) {
            host = row["host"]
        }
    }
    
    final class SafariFavicon {
        let host: String
        let imageData: Data
        
        var image: NSImage? {
            NSImage(data: imageData)
        }
        
        fileprivate init(host: String, imageData: Data) {
            self.host = host
            self.imageData = imageData
        }
    }

    private let safariFaviconsDatabaseURL: URL

    init(safariDataDirectoryURL: URL) {
        self.safariFaviconsDatabaseURL = safariDataDirectoryURL
            .appendingPathComponent("Touch Icons Cache")
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
                guard let imageData = fetchImageData(with: record.host) else {
                    return nil
                }

                guard let formattedHost = record.formattedHost else {
                    return nil
                }

                return SafariFavicon(host: formattedHost, imageData: imageData)
            }

            let faviconsByURL = Dictionary(grouping: favicons, by: { $0.host })
            
            return .success(faviconsByURL)
        } catch {
            return .failure(.unexpectedFaviconsDatabaseFormat)
        }
    }
    
    private func fetchImageData(with host: String) -> Data? {
        guard let hostData = host.data(using: .utf8) else {
            return nil
        }

        let imageUUID = CryptoKit.Insecure.MD5.hash(data: hostData)
        let hash = imageUUID.map {
            String(format: "%02hhx", $0)
        }.joined().uppercased()

        let faviconsDirectoryURL = safariFaviconsDatabaseURL.deletingLastPathComponent()
        let faviconURL = faviconsDirectoryURL.appendingPathComponent("Images").appendingPathComponent(hash).appendingPathExtension("png")
        
        return try? Data(contentsOf: faviconURL)
    }

    // MARK: - Database Queries

    func allFaviconsQuery() -> String {
        return """
        SELECT
            host
        FROM
            cache_settings;
        """
    }

}
