//
//  ChromiumBookmarksReader.swift
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

final class ChromiumBookmarksReader {

    enum Constants {
        static let defaultBookmarksFileName = "Bookmarks"
    }

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case fileRead
            case decodeJson
        }

        var action: DataImportAction { .bookmarks }
        let source: DataImport.Source
        let type: OperationType
        let underlyingError: Error?
    }
    func importError(type: ImportError.OperationType, underlyingError: Error) -> ImportError {
        ImportError(source: source, type: type, underlyingError: underlyingError)
    }

    private let chromiumBookmarksFileURL: URL
    private let source: DataImport.Source

    init(chromiumDataDirectoryURL: URL, source: DataImport.Source, bookmarksFileName: String = Constants.defaultBookmarksFileName) {
        self.chromiumBookmarksFileURL = chromiumDataDirectoryURL.appendingPathComponent(bookmarksFileName)
        self.source = source
    }

    func readBookmarks() -> DataImportResult<ImportedBookmarks> {
        var currentOperationType: ImportError.OperationType = .fileRead
        do {
            let bookmarksFileData = try Data(contentsOf: chromiumBookmarksFileURL)
            currentOperationType = .decodeJson
            let decodedBookmarks = try JSONDecoder().decode(ImportedBookmarks.self, from: bookmarksFileData)
            return .success(decodedBookmarks)
        } catch {
            return .failure(importError(type: currentOperationType, underlyingError: error))
        }
    }

}
