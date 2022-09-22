//
//  BookmarkHTMLImporter.swift
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

final class BookmarkHTMLImporter: DataImporter {

    let fileURL: URL
    let bookmarkImporter: BookmarkImporter

    init(fileURL: URL, bookmarkImporter: BookmarkImporter) {
        self.fileURL = fileURL
        self.bookmarkImporter = bookmarkImporter
    }

    var totalBookmarks: Int {
        (try? bookmarkReaderResult.get().bookmarks.numberOfBookmarks) ?? 0
    }

    func importableTypes() -> [DataImport.DataType] {
        [.bookmarks]
    }

    func importData(
        types: [DataImport.DataType],
        from profile: DataImport.BrowserProfile?,
        completion: @escaping (Result<DataImport.Summary, DataImportError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {

            switch self.bookmarkReaderResult {
            case let .success(importedData):
                do {
                    let source: BookmarkImportSource = importedData.source ?? .thirdPartyBrowser(.bookmarksHTML)
                    let bookmarksResult = try self.bookmarkImporter.importBookmarks(importedData.bookmarks, source: source)
                    DispatchQueue.main.async {
                        completion(.success(.init(bookmarksResult: bookmarksResult)))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(.bookmarks(.cannotAccessCoreData)))
                    }
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    completion(.failure(.bookmarks(error)))
                }
            }
        }
    }

    private lazy var bookmarkReaderResult: Result<HTMLImportedBookmarks, BookmarkHTMLReader.ImportError> = {
        let bookmarkReader = BookmarkHTMLReader(bookmarksFileURL: self.fileURL)
        return bookmarkReader.readBookmarks()
    }()
}
