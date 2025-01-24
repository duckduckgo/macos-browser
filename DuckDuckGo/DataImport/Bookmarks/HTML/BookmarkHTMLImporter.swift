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
import BrowserServicesKit

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

    var importableTypes: [DataImport.DataType] {
        return [.bookmarks]
    }

    func importData(types: Set<DataImport.DataType>) -> DataImportTask {
        assert(types.contains(.bookmarks))
        return .detachedWithProgress { updateProgress in
            [.bookmarks: self.importDataSync(types: types, updateProgress: updateProgress)]
        }
    }
    private func importDataSync(types: Set<DataImport.DataType>, updateProgress: DataImportProgressCallback) -> DataImportResult<DataImport.DataTypeSummary> {
        switch self.bookmarkReaderResult {
        case let .success(importedData):
            let source: BookmarkImportSource = importedData.source ?? .thirdPartyBrowser(.bookmarksHTML)
            let bookmarksResult = self.bookmarkImporter.importBookmarks(importedData.bookmarks, source: source)
            return .success(.init(bookmarksResult))

        case let .failure(error):
            return .failure(error)
        }
    }

    private lazy var bookmarkReaderResult: DataImportResult<HTMLImportedBookmarks> = {
        let bookmarkReader = BookmarkHTMLReader(bookmarksFileURL: self.fileURL)
        return bookmarkReader.readBookmarks()
    }()
}
