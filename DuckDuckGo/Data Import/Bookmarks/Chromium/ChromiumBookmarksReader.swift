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

    enum ImportError: Error {
        case noBookmarksFileFound
        case bookmarksFileDecodingFailed
    }

    enum Constants {
        static let defaultBookmarksFileName = "Bookmarks"
    }

    private let chromiumBookmarksFileURL: URL

    init(chromiumDataDirectoryURL: URL, bookmarksFileName: String = Constants.defaultBookmarksFileName) {
        self.chromiumBookmarksFileURL = chromiumDataDirectoryURL.appendingPathComponent(bookmarksFileName)
    }

    func readBookmarks() -> Result<ImportedBookmarks, ChromiumBookmarksReader.ImportError> {
        guard let bookmarksFileData = try? Data(contentsOf: chromiumBookmarksFileURL) else {
            return .failure(.noBookmarksFileFound)
        }

        do {
            let decodedBookmarks = try JSONDecoder().decode(ImportedBookmarks.self, from: bookmarksFileData)
            return .success(decodedBookmarks)
        } catch {
            return .failure(.bookmarksFileDecodingFailed)
        }
    }

}
