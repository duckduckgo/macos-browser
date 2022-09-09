//
//  SafariHistoryReader.swift
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

final class SafariHistoryReader {

    enum ImportError: Error {
        case noHistoryFileFound
        case failedToTemporarilyCopyFile
        case unexpectedHistoryDatabaseFormat
    }

    private let safariHistoryDatabaseURL: URL

    init(safariHistoryDatabaseURL: URL) {
        self.safariHistoryDatabaseURL = safariHistoryDatabaseURL
    }

    func readHistory() -> Result<[ImportedHistoryVisit], SafariHistoryReader.ImportError> {
        do {
            return try safariHistoryDatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                return readHistory(fromDatabaseURL: temporaryDatabaseURL)
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }

    // MARK: - Private

    private func readHistory(fromDatabaseURL databaseURL: URL) -> Result<[ImportedHistoryVisit], SafariHistoryReader.ImportError> {
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

            let timestamp: TimeInterval = row["visit_time"]
            date = Date(macTimestamp: timestamp)
        }
    }

    // MARK: - Database Queries

    func historyEntriesQuery(since date: Date) -> String {
        return """
        SELECT
            history_items.url,
            history_visits.title,
            history_visits.visit_time
        FROM
            history_visits
        LEFT JOIN
            history_items
        ON
            history_visits.history_item = history_items.id
        WHERE
            history_visits.visit_time >= \(date.macTimestamp)
        ORDER BY
            history_visits.visit_time
        ;
        """
    }

}

private extension ImportedHistoryVisit {

    init?(_ row: SafariHistoryReader.HistoryRow) {
        guard let url = row.url.url else {
            return nil
        }
        self.url = url
        title = row.title
        date = row.date
    }
}
