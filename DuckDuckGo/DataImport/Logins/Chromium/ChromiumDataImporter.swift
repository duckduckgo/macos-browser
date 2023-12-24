//
//  ChromiumDataImporter.swift
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

internal class ChromiumDataImporter: DataImporter {

    private let bookmarkImporter: BookmarkImporter
    private let loginImporter: LoginImporter?
    private let faviconManager: FaviconManagement
    private let profile: DataImport.BrowserProfile
    private var source: DataImport.Source {
        profile.browser.importSource
    }

    init(profile: DataImport.BrowserProfile, loginImporter: LoginImporter?, bookmarkImporter: BookmarkImporter, faviconManager: FaviconManagement) {
        self.profile = profile
        self.loginImporter = loginImporter
        self.bookmarkImporter = bookmarkImporter
        self.faviconManager = faviconManager
    }

    convenience init(profile: DataImport.BrowserProfile, loginImporter: LoginImporter?, bookmarkImporter: BookmarkImporter) {
        self.init(profile: profile,
                  loginImporter: loginImporter,
                  bookmarkImporter: bookmarkImporter,
                  faviconManager: FaviconManager.shared)
    }

    var importableTypes: [DataImport.DataType] {
        return [.passwords, .bookmarks]
    }

    func importData(types: Set<DataImport.DataType>) -> DataImportTask {
        .detachedWithProgress { updateProgress in
            do {
                let result = try await self.importDataSync(types: types, updateProgress: updateProgress)
                return result
            } catch is CancellationError {
            } catch {
                assertionFailure("Only CancellationError should be thrown here")
            }
            return [:]
        }
    }

    private func importDataSync(types: Set<DataImport.DataType>, updateProgress: @escaping DataImportProgressCallback) async throws -> DataImportSummary {
        var summary = DataImportSummary()

        let dataTypeFraction = 1.0 / Double(types.count)

        if types.contains(.passwords), let loginImporter {
            try updateProgress(.importingPasswords(numberOfPasswords: nil, fraction: 0.0))

            let loginReader = ChromiumLoginReader(chromiumDataDirectoryURL: profile.profileURL, source: source)
            let loginResult = loginReader.readLogins(modalWindow: nil)

            let loginsSummary = try loginResult.flatMap { logins in
                do {
                    return try .success(loginImporter.importLogins(logins) { count in
                        try updateProgress(.importingPasswords(numberOfPasswords: count,
                                                               fraction: dataTypeFraction * (0.5 + Double(count) / Double(logins.count))))
                    })
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    return .failure(LoginImporterError(error: error))
                }
            }

            summary[.passwords] = loginsSummary

            try updateProgress(.importingPasswords(numberOfPasswords: try? loginResult.get().count, fraction: dataTypeFraction * 1.0))
        }

        let passwordsFraction: Double = types.contains(.passwords) ? 0.5 : 0.0
        if types.contains(.bookmarks)
            // don‘t proceed with bookmarks import on Keychain prompt denial
            && (summary[.passwords]?.error as? ChromiumLoginReader.ImportError)?.type != .userDeniedKeychainPrompt {

            try updateProgress(.importingBookmarks(numberOfBookmarks: nil, fraction: passwordsFraction + 0.0))

            let bookmarkReader = ChromiumBookmarksReader(chromiumDataDirectoryURL: profile.profileURL)
            let bookmarkResult = bookmarkReader.readBookmarks()

            try updateProgress(.importingBookmarks(numberOfBookmarks: try? bookmarkResult.get().numberOfBookmarks,
                                                   fraction: passwordsFraction + dataTypeFraction * 0.5))

            let bookmarksSummary = bookmarkResult.map { bookmarks in
                bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(source))
            }

            if case .success = bookmarksSummary {
                await importFavicons()
            }

            summary[.bookmarks] = bookmarksSummary.map { .init($0) }

            try updateProgress(.importingBookmarks(numberOfBookmarks: try? bookmarkResult.get().numberOfBookmarks,
                                                   fraction: passwordsFraction + dataTypeFraction * 1.0))
        }

        return summary
    }

    private func importFavicons() async {
        let faviconsReader = ChromiumFaviconsReader(chromiumDataDirectoryURL: profile.profileURL)
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
            Pixel.fire(.dataImportFailed(source: source, sourceVersion: profile.installedAppsMajorVersionDescription(), error: error))
        }
    }

    func requiresKeychainPassword(for selectedDataTypes: Set<DataImport.DataType>) -> Bool {
        return selectedDataTypes.contains(.passwords)
    }

}
