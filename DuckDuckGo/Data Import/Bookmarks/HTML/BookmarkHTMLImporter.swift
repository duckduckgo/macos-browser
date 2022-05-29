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
        let bookmarkReader = BookmarkHTMLReader(bookmarksFileURL: fileURL)
        let result = bookmarkReader.readBookmarks()
        switch result {
        case let .success(importedData):
            return importedData.bookmarkCount
        case .failure:
            return 0
        }
    }

    func importableTypes() -> [DataImport.DataType] {
        [.bookmarks]
    }

    func importData(
        types: [DataImport.DataType],
        from profile: DataImport.BrowserProfile?,
        completion: @escaping (Result<DataImport.Summary, DataImportError>) -> Void
    ) {
        var summary = DataImport.Summary()

        if types.contains(.bookmarks) {
            let bookmarkReader = BookmarkHTMLReader(bookmarksFileURL: fileURL)
            let bookmarkResult = bookmarkReader.readBookmarks()

            switch bookmarkResult {
            case let .success(importedData):
                do {
                    let source: BookmarkImportSource = importedData.isInSafariFormat ? .safari : .chromium
                    summary.bookmarksResult = try bookmarkImporter.importBookmarks(importedData.bookmarks, source: source)
                } catch {
                    completion(.failure(.bookmarks(.cannotAccessCoreData)))
                    return
                }
            case let .failure(error):
                completion(.failure(.bookmarks(error)))
                return
            }
        }

        completion(.success(summary))
    }

}
