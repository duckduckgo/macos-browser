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

final class SafariDataImporter: DataImporter {

    @MainActor
    static func requestDataDirectoryPermission(for dataDirectoryUrl: URL) -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = dataDirectoryUrl
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

    init(source: DataImport.Source, profileURL: URL, bookmarkImporter: BookmarkImporter, faviconManager: FaviconManagement = FaviconManager.shared) {
        self.safariDataDirectoryUrl = profileURL
        self.bookmarkImporter = bookmarkImporter
        self.faviconManager = faviconManager
    }

    var importableTypes: [DataImport.DataType] {
        return [.bookmarks]
    }

    func importData(types: Set<DataImport.DataType>) -> DataImportTask {
        .detachedWithProgress { updateProgress in
            let result = await self.importDataSync(types: types, updateProgress: updateProgress)
            return result
        }
    }

    static private let bookmarksFileName = "Bookmarks.plist"

    private var fileUrl: URL {
        safariDataDirectoryUrl.appendingPathComponent(Self.bookmarksFileName)
    }

    func validateAccess(for types: Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]? {
        guard types.contains(.bookmarks) else { return nil }

        if case .failure(let error) = SafariBookmarksReader(safariBookmarksFileURL: fileUrl).validateFileReadAccess() {
            return [.bookmarks: error]
        }
        return nil
    }

    @MainActor
    private func importDataSync(types: Set<DataImport.DataType>, updateProgress: DataImportProgressCallback) async -> DataImportSummary {
        // logins will be imported from CSV
        guard types.contains(.bookmarks) else { return [:] }

        let bookmarkReader = SafariBookmarksReader(safariBookmarksFileURL: fileUrl)
        let bookmarkResult = bookmarkReader.readBookmarks()

        let summary = bookmarkResult.map { bookmarks in
            bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(.safari))
        }

        if case .success = summary {
            await importFavicons(from: safariDataDirectoryUrl)
        }

        return [.bookmarks: summary.map { .init($0) }]
    }

    private func importFavicons(from dataDirectoryURL: URL) async {
        let faviconsReader = SafariFaviconsReader(safariDataDirectoryURL: dataDirectoryURL)
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
            await faviconManager.handleFaviconsByDocumentUrl(faviconsByDocument)

        case .failure(let error):
            Pixel.fire(.dataImportFailed(error))
        }
    }

}
