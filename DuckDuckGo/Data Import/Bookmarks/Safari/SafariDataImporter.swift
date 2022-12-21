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
        return FileManager.default.isReadableFile(atPath: safariDataDirectoryURL.path)
    }

    static func requestSafariDataDirectoryPermission() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = safariDataDirectoryURL
        openPanel.message = UserText.bookmarkImportSafariRequestPermissionButtonTitle
        openPanel.allowedFileTypes = nil
        openPanel.allowsOtherFileTypes = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true

        _ = openPanel.runModal()
        return openPanel.urls.first
    }

    static private var safariDataDirectoryURL: URL {
        let applicationSupport = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return applicationSupport.appendingPathComponent("Safari/")
    }

    static private var bookmarksFileURL: URL {
        return safariDataDirectoryURL.appendingPathComponent("Bookmarks.plist")
    }

    private let bookmarkImporter: BookmarkImporter
    private let faviconManager: FaviconManagement

    init(bookmarkImporter: BookmarkImporter, faviconManager: FaviconManagement) {
        self.bookmarkImporter = bookmarkImporter
        self.faviconManager = faviconManager
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

            let faviconsReader = SafariFaviconsReader(safariDataDirectoryURL: Self.safariDataDirectoryURL)
            let faviconsResult = faviconsReader.readFavicons()

            switch faviconsResult {
            case .success(let faviconsByURL):
                for (pageURLString, fetchedFavicons) in faviconsByURL {
                    if let pageURL = URL(string: pageURLString) {
                        let favicons = fetchedFavicons.map {
                            Favicon(identifier: UUID(),
                                    url: pageURL,
                                    image: $0.image,
                                    relation: .icon,
                                    documentUrl: pageURL,
                                    dateCreated: Date())
                        }

                        faviconManager.handleFavicons(favicons, documentUrl: pageURL)
                    }
                }

            case .failure:
                Pixel.fire(.faviconImportFailed(source: .safari))
            }

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
