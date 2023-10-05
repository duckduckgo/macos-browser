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

protocol DataDirectoryPermissionAuthorization {
    func canReadBookmarksFile() -> Bool
    func requestDataDirectoryPermission() -> URL?
}

final class SafariDataImporter: DataImporter, DataDirectoryPermissionAuthorization {

    func canReadBookmarksFile() -> Bool {
        return FileManager.default.isReadableFile(atPath: safariDataDirectoryUrl.path)
    }

    func requestDataDirectoryPermission() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = safariDataDirectoryUrl
        openPanel.message = UserText.bookmarkImportSafariRequestPermissionButtonTitle
        openPanel.allowsOtherFileTypes = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true

        _ = openPanel.runModal()
        return openPanel.urls.first
    }

    private let safariDataDirectoryUrl: URL
    private let bookmarkImporter: BookmarkImporter
    private let faviconManager: FaviconManagement

    init(safariDataDirectoryUrl: URL, bookmarkImporter: BookmarkImporter, faviconManager: FaviconManagement) {
        self.safariDataDirectoryUrl = safariDataDirectoryUrl
        self.bookmarkImporter = bookmarkImporter
        self.faviconManager = faviconManager
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.bookmarks]
    }

    @MainActor(unsafe)
    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (DataImportResult<DataImport.Summary>) -> Void) {
        let result = importData(types: types, from: profile)
        completion(result)
    }

    static private let bookmarksFileName = "Bookmarks.plist"

    @MainActor
    private func importData(types: [DataImport.DataType], from profile: DataImport.BrowserProfile?) -> DataImportResult<DataImport.Summary> {
        var summary = DataImport.Summary()

        if types.contains(.bookmarks) {
            let fileUrl = safariDataDirectoryUrl.appendingPathComponent(Self.bookmarksFileName)
            let bookmarkReader = SafariBookmarksReader(safariBookmarksFileURL: fileUrl)
            let bookmarkResult = bookmarkReader.readBookmarks()

            let faviconsReader = SafariFaviconsReader(safariDataDirectoryURL: safariDataDirectoryUrl)
            let faviconsResult = faviconsReader.readFavicons()

            switch faviconsResult {
            case .success(let faviconsByURL):
                let faviconsByDocument = faviconsByURL.reduce(into: [URL: [Favicon]]()) { result, pair in
                    guard let pageURL = URL(string: pair.key) else { return }
                    let favicons = pair.value.map {
                        Favicon(identifier: UUID(),
                                url: pageURL,
                                image: $0.image,
                                relation: .icon,
                                documentUrl: pageURL,
                                dateCreated: Date())
                    }
                    result[pageURL] = favicons
                }
                faviconManager.handleFaviconsByDocumentUrl(faviconsByDocument)

            case .failure(let error):
                Pixel.fire(.dataImportFailed(error))
            }

            switch bookmarkResult {
            case .success(let bookmarks):
                summary.bookmarksResult = bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(.safari))
            case .failure(let error):
                return .failure(error)
            }
        }

        if types.contains(.logins) {
            summary.loginsResult = .awaited
        }

        return .success(summary)
    }

}
