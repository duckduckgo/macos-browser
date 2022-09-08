//
//  FirefoxHistoryReader.swift
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

final class FirefoxHistoryReader {

    enum Constants {
        static let placesDatabaseName = "places.sqlite"
    }

    enum ImportError: Error {
        case noHistoryFileFound
        case failedToTemporarilyCopyFile
        case unexpectedHistoryDatabaseFormat
    }

    private let firefoxPlacesDatabaseURL: URL

    init(firefoxDataDirectoryURL: URL) {
        self.firefoxPlacesDatabaseURL = firefoxDataDirectoryURL.appendingPathComponent(Constants.placesDatabaseName)
    }

    func readHistory() -> Result<[ImportedHistoryVisit], FirefoxHistoryReader.ImportError> {
        do {
            return try firefoxPlacesDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readHistory(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readHistory(fromDatabaseURL databaseURL: URL) -> Result<[ImportedHistoryVisit], FirefoxHistoryReader.ImportError> {
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)

            let visits: [ImportedHistoryVisit] = try queue.read { database in

                guard let rootEntries = try? HistoryRow.fetchAll(database, sql: historyEntriesQuery(since: .monthAgo)) else {
                    throw ImportError.unexpectedHistoryDatabaseFormat
                }

                return rootEntries.compactMap(ImportedHistoryVisit.init)
            }

            return .success(visits)
        } catch {
            return .failure(.unexpectedHistoryDatabaseFormat)
        }
    }

    fileprivate struct HistoryRow: FetchableRecord {
        let url: String
        let title: String?
        let date: Date

        init(row: Row) {
            url = row["url"]
            title = row["title"]
            let timestamp: Int = row["visit_date"]
            date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1e6)
        }
    }

    // MARK: - Database Queries

    func historyEntriesQuery(since date: Date) -> String {
        return """
        SELECT
            moz_places.url,
            moz_places.title,
            moz_historyvisits.visit_date
        FROM
            moz_historyvisits
        LEFT JOIN
            moz_places
        ON
            moz_historyvisits.place_id = moz_places.id
        WHERE
            moz_historyvisits.visit_date >= \(Int(date.timeIntervalSince1970 * 1e6))
        ORDER BY
            moz_historyvisits.visit_date
        ;
        """
    }

}

private extension ImportedHistoryVisit {

    init?(_ row: FirefoxHistoryReader.HistoryRow) {
        guard let url = row.url.url else {
            return nil
        }
        self.url = url
        title = row.title
        date = row.date
    }
}
