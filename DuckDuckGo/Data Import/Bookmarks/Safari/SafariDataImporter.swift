//
//  SafariDataImporter.swift
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

internal class SafariDataImporter: DataImporter {

    static func canReadBookmarksFile() -> Bool {
        // This is inefficient, but regular FileManager APIs believe this file is unreadable even when granted permission via NSOpenPanel.
        guard let data = try? Data(contentsOf: bookmarksFileURL) else {
            return false
        }

        return !data.isEmpty
    }

    static func requestBookmarksFilePermission() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = bookmarksFileURL
        openPanel.message = UserText.bookmarkImportSafariRequestPermissionButtonTitle
        openPanel.allowedFileTypes = ["plist"]
        openPanel.allowsOtherFileTypes = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        _ = openPanel.runModal()
        return openPanel.urls.first
    }

    static private var bookmarksFileURL: URL {
        let applicationSupport = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let path = applicationSupport.appendingPathComponent("Safari/")

        return path.appendingPathComponent("Bookmarks.plist")
    }

    private let bookmarkImporter: BookmarkImporter

    init(bookmarkImporter: BookmarkImporter) {
        self.bookmarkImporter = bookmarkImporter
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.bookmarks]
    }

    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (Result<DataImport.Summary, DataImportError>) -> Void) {
        var summary = DataImport.Summary()

        if types.contains(.bookmarks) {
            let bookmarkReader = SafariBookmarksReader(safariBookmarksFileURL: Self.bookmarksFileURL)
            let bookmarkResult = bookmarkReader.readBookmarks()

            switch bookmarkResult {
            case .success(let bookmarks):
                do {
                    summary.bookmarksResult = try bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(.safari))
                } catch {
                    completion(.failure(.bookmarks(.cannotAccessCoreData)))
                    return
                }
            case .failure(let error):
                completion(.failure(.bookmarks(error)))
                return
            }
        }

        if types.contains(.logins) {
            summary.loginsResult = .awaited
        }

        completion(.success(summary))
    }

}
