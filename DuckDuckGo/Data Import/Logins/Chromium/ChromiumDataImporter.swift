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
    
    var source: DataImport.Source {
        fatalError("Subclasses must return a source")
    }

    private let applicationDataDirectoryURL: URL
    private let bookmarkImporter: BookmarkImporter
    private let loginImporter: LoginImporter

    init(applicationDataDirectoryURL: URL, loginImporter: LoginImporter, bookmarkImporter: BookmarkImporter) {
        self.applicationDataDirectoryURL = applicationDataDirectoryURL
        self.loginImporter = loginImporter
        self.bookmarkImporter = bookmarkImporter
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.logins, .bookmarks]
    }

    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (Result<DataImport.Summary, DataImportError>) -> Void) {
        
        var summary = DataImport.Summary()
        let dataDirectoryURL = profile?.profileURL ?? applicationDataDirectoryURL

        if types.contains(.logins) {
            let loginReader = ChromiumLoginReader(chromiumDataDirectoryURL: dataDirectoryURL, processName: processName)
            let loginResult = loginReader.readLogins()

            switch loginResult {
            case .success(let logins):
                do {
                    summary.loginsResult = .completed(try loginImporter.importLogins(logins))
                } catch {
                    completion(.failure(.logins(.cannotAccessSecureVault)))
                    return
                }
            case .failure(let error):
                completion(.failure(.logins(error)))
                return
            }
        }

        if types.contains(.bookmarks) {
            let bookmarkReader = ChromiumBookmarksReader(chromiumDataDirectoryURL: dataDirectoryURL)
            let bookmarkResult = bookmarkReader.readBookmarks()

            switch bookmarkResult {
            case .success(let bookmarks):
                do {
                    summary.bookmarksResult = try bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(source))
                } catch {
                    completion(.failure(.bookmarks(.cannotAccessSecureVault)))
                    return
                }
            case .failure(let error):
                switch error {
                case .noBookmarksFileFound:
                    // If there are no bookmarks, treat it as a successful import of zero bookmarks.
                    let result = BookmarkImportResult.init(successful: 0, duplicates: 0, failed: 0)
                    summary.bookmarksResult = result

                case .bookmarksFileDecodingFailed:
                    completion(.failure(.bookmarks(.cannotReadFile)))
                    return
                }
            }
        }

        completion(.success(summary))
    }

}
