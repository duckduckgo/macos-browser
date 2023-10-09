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

    var processName: String {
        "Chromium"
    }

    var source: DataImport.Source {
        .chromium
    }

    private let applicationDataDirectoryURL: URL
    private let bookmarkImporter: BookmarkImporter
    private let loginImporter: LoginImporter
    private let faviconManager: FaviconManagement

    init(applicationDataDirectoryURL: URL, loginImporter: LoginImporter, bookmarkImporter: BookmarkImporter, faviconManager: FaviconManagement) {
        self.applicationDataDirectoryURL = applicationDataDirectoryURL
        self.loginImporter = loginImporter
        self.bookmarkImporter = bookmarkImporter
        self.faviconManager = faviconManager
    }

    convenience init(loginImporter: LoginImporter, bookmarkImporter: BookmarkImporter) {
        let applicationSupport = URL.nonSandboxApplicationSupportDirectoryURL
        let defaultDataURL = applicationSupport.appendingPathComponent("Chromium/Default/")

        self.init(applicationDataDirectoryURL: defaultDataURL,
                  loginImporter: loginImporter,
                  bookmarkImporter: bookmarkImporter,
                  faviconManager: FaviconManager.shared)
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.logins, .bookmarks]
    }

    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (DataImportResult<DataImport.Summary>) -> Void) {
        let result = importData(types: types, from: profile)
        completion(result)
    }

    private func importData(types: [DataImport.DataType], from profile: DataImport.BrowserProfile?) -> DataImportResult<DataImport.Summary> {
        var summary = DataImport.Summary()
        let dataDirectoryURL = profile?.profileURL ?? applicationDataDirectoryURL

        if types.contains(.logins) {
            let loginReader = ChromiumLoginReader(chromiumDataDirectoryURL: dataDirectoryURL, source: source, processName: processName)
            let loginResult = loginReader.readLogins()

            switch loginResult {
            case .success(let logins):
                do {
                    let result = try loginImporter.importLogins(logins)
                    summary.loginsResult = .completed(result)
                } catch {
                    return .failure(LoginImporterError(source: source, error: error))
                }
            case .failure(let error):
                return .failure(error)
            }
        }

        if types.contains(.bookmarks) {
            let bookmarkReader = ChromiumBookmarksReader(chromiumDataDirectoryURL: dataDirectoryURL, source: source)
            let bookmarkResult = bookmarkReader.readBookmarks()

            importFavicons(from: dataDirectoryURL)

            switch bookmarkResult {
            case .success(let bookmarks):
                summary.bookmarksResult = bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(source))

            case .failure(let error):
                return .failure(error)
            }
        }

        return .success(summary)
    }

    @MainActor(unsafe)
    func importFavicons(from dataDirectoryURL: URL) {
        let faviconsReader = ChromiumFaviconsReader(chromiumDataDirectoryURL: dataDirectoryURL, source: source)
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
    }

}
