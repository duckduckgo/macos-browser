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

import AppKit
import Foundation
import Common
import CryptoKit
import GRDB
import os.log
import BrowserServicesKit

final class SafariFaviconsReader {

    enum Constants {
        static let faviconsDatabaseName = "TouchIconCacheSettings.db"
    }

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case copyTemporaryFile
            case dbOpen
            case fetchAllFavicons
        }

        var action: DataImportAction { .favicons }
        let type: OperationType
        let underlyingError: Error?

        var errorType: DataImport.ErrorType { .other }
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

        init(row: Row) throws {
            host = try row["host"] ?? { throw FetchableRecordError<SafariFaviconRecord>(column: 0) }()
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
    private var currentOperationType: ImportError.OperationType = .copyTemporaryFile

    init(safariDataDirectoryURL: URL) {
        self.safariFaviconsDatabaseURL = safariDataDirectoryURL
            .appendingPathComponent("Touch Icons Cache")
            .appendingPathComponent(Constants.faviconsDatabaseName)
    }

    func readFavicons() -> DataImportResult<[String: [SafariFavicon]]> {
        do {
            currentOperationType = .copyTemporaryFile
            return try safariFaviconsDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                let favicons = try readFavicons(fromDatabaseURL: temporaryDatabaseURL)
                return .success(favicons)
            }
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(ImportError(type: currentOperationType, underlyingError: error))
        }
    }

    // MARK: - Private

    private func readFavicons(fromDatabaseURL databaseURL: URL) throws -> [String: [SafariFavicon]] {
        currentOperationType = .dbOpen
        let queue = try DatabaseQueue(path: databaseURL.path)

        currentOperationType = .fetchAllFavicons
        let faviconRecords: [SafariFaviconRecord] = try queue.read { database in
            try SafariFaviconRecord.fetchAll(database, sql: allFaviconsQuery())
        }

        let favicons: [SafariFavicon] = faviconRecords.compactMap { record in
            let imageData: Data
            do {
                imageData = try readImageData(with: record.host)
            } catch {
                Logger.dataImportExport.error("could not read image data for \(record.host): \(error.localizedDescription)")
                return nil
            }
            guard let formattedHost = record.formattedHost else { return nil }

            return SafariFavicon(host: formattedHost, imageData: imageData)
        }

        let faviconsByURL = Dictionary(grouping: favicons, by: { $0.host })

        return faviconsByURL
    }

    private func readImageData(with host: String) throws -> Data {
        let hostData = host.utf8data
        let imageUUID = CryptoKit.Insecure.MD5.hash(data: hostData)
        let hash = imageUUID.map {
            String(format: "%02hhx", $0)
        }.joined().uppercased()

        let faviconsDirectoryURL = safariFaviconsDatabaseURL.deletingLastPathComponent()
        let faviconURL = faviconsDirectoryURL.appendingPathComponent("Images").appendingPathComponent(hash).appendingPathExtension("png")

        return try Data(contentsOf: faviconURL)
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
