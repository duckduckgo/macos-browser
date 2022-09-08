//
//  ChromiumHistoryReader.swift
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

final class ChromiumHistoryReader {

    enum Constants {
        static let historyDatabaseName = "History"
    }

    enum ImportError: Error {
        case noHistoryFileFound
        case failedToTemporarilyCopyFile
        case unexpectedHistoryDatabaseFormat
    }

    private let chromiumHistoryDatabaseURL: URL

    init(chromiumDataDirectoryURL: URL) {
        chromiumHistoryDatabaseURL = chromiumDataDirectoryURL.appendingPathComponent(Constants.historyDatabaseName)
    }

    func readHistory() -> Result<[ImportedHistoryVisit], ChromiumHistoryReader.ImportError> {
        do {
            return try chromiumHistoryDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readHistory(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readHistory(fromDatabaseURL databaseURL: URL) -> Result<[ImportedHistoryVisit], ChromiumHistoryReader.ImportError> {
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

            if let title: String = row["title"], !title.isEmpty {
                self.title = title
            } else {
                self.title = nil
            }

            let timestamp: Int64 = row["visit_time"]
            date = Date(chromiumTimestamp: timestamp)
        }
    }

    // MARK: - Database Queries

    func historyEntriesQuery(since date: Date) -> String {
        return """
        SELECT
            urls.url,
            urls.title,
            visits.visit_time
        FROM
            visits
        LEFT JOIN
            urls
        ON
            urls.id = visits.url
        WHERE
            visits.visit_time >= \(date.chromiumTimestamp)
        ORDER BY
            visits.visit_time
        ;
        """
    }

}

private extension ImportedHistoryVisit {

    init?(_ row: ChromiumHistoryReader.HistoryRow) {
        guard let url = row.url.url else {
            return nil
        }
        self.url = url
        title = row.title
        date = row.date
    }
}
