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

import AppKit
import PixelKit
import BrowserServicesKit

final class SafariDataImporter: DataImporter {

    @MainActor
    static func requestDataDirectoryPermission(for fileUrl: URL) -> URL? {
        let openPanel = NSOpenPanel()
        // if file does not exist, grant permission to its parent folder
        openPanel.directoryURL = fileUrl.deletingLastPathComponent()
        openPanel.message = UserText.bookmarkImportSafariRequestPermissionButtonTitle
        openPanel.allowsOtherFileTypes = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true

        _ = openPanel.runModal()
        return openPanel.urls.first
    }

    private let bookmarkImporter: BookmarkImporter
    private let faviconManager: FaviconManagement
    private let profile: DataImport.BrowserProfile
    private var source: DataImport.Source {
        profile.browser.importSource
    }

    init(profile: DataImport.BrowserProfile, bookmarkImporter: BookmarkImporter, faviconManager: FaviconManagement = FaviconManager.shared) {
        self.profile = profile
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

    static let bookmarksFileName = "Bookmarks.plist"

    private var fileUrl: URL {
        profile.profileURL.appendingPathComponent(Self.bookmarksFileName)
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
            bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(source))
        }

        if case .success = summary {
            await importFavicons(from: profile.profileURL)
        }

        return [.bookmarks: summary.map { .init($0) }]
    }

    private func importFavicons(from dataDirectoryURL: URL) async {
        let faviconsReader = SafariFaviconsReader(safariDataDirectoryURL: dataDirectoryURL)
        let faviconsResult = faviconsReader.readFavicons()
        let sourceVersion = profile.installedAppsMajorVersionDescription()

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
            PixelKit.fire(GeneralPixel.dataImportSucceeded(action: .favicons, source: source, sourceVersion: sourceVersion))

        case .failure(let error):
            PixelKit.fire(GeneralPixel.dataImportFailed(source: source, sourceVersion: sourceVersion, error: error))
        }
    }

}
