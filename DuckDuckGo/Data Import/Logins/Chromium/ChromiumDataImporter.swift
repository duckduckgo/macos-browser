//
//  ChromiumDataImporter.swift
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

internal class ChromiumDataImporter: DataImporter {

    var processName: String {
        fatalError("Subclasses must provide their own process name")
    }

    private let applicationDataDirectoryPath: String
    private let bookmarkImporter: BookmarkImporter
    private let loginImporter: LoginImporter

    init(applicationDataDirectoryPath: String, loginImporter: LoginImporter, bookmarkImporter: BookmarkImporter) {
        self.applicationDataDirectoryPath = applicationDataDirectoryPath
        self.loginImporter = loginImporter
        self.bookmarkImporter = bookmarkImporter
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.logins, .bookmarks]
    }

    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (Result<[DataImport.Summary], DataImportError>) -> Void) {
        var summaries = [DataImport.Summary]()
        let dataDirectoryPath = profile?.profileURL.path ?? applicationDataDirectoryPath

        if types.contains(.logins) {
            let loginReader = ChromiumLoginReader(chromiumDataDirectoryPath: dataDirectoryPath, processName: processName)
            let loginResult = loginReader.readLogins()

            switch loginResult {
            case .success(let logins):
                do {
                    let summary = try loginImporter.importLogins(logins)
                    summaries.append(summary)
                } catch {
                    completion(.failure(.cannotAccessSecureVault))
                    return
                }
            case .failure:
                completion(.failure(.browserNeedsToBeClosed))
                return
            }
        }

        if types.contains(.bookmarks) {
            let bookmarkReader = ChromiumBookmarksReader(chromiumDataDirectoryPath: dataDirectoryPath)
            let bookmarkResult = bookmarkReader.readBookmarks()

            switch bookmarkResult {
            case .success(let bookmarks):
                do {
                    let summary = try bookmarkImporter.importBookmarks(bookmarks)
                    summaries.append(summary)
                } catch {
                    completion(.failure(.cannotAccessSecureVault))
                    return
                }
            case .failure(let error):
                switch error {
                case .noBookmarksFileFound:
                    // If there is are no bookmarks, treat it as a successful import of zero bookmarks.
                    let result = BookmarkImportResult.init(successful: 0, duplicates: 0, failed: 0)
                    let summary = DataImport.Summary.bookmarks(result: result)
                    summaries.append(summary)
                case .bookmarksFileDecodingFailed:
                    completion(.failure(.cannotReadFile))
                    return
                }
            }
        }

        completion(.success(summaries))
    }

}
