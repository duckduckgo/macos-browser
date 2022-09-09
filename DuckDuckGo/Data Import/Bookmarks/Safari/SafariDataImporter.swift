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

    static func canReadCookiesFile() -> Bool {
        // This is inefficient, but regular FileManager APIs believe this file is unreadable even when granted permission via NSOpenPanel.
        guard let data = try? Data(contentsOf: cookiesFileURL) else {
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

    static func requestCookiesFilePermission() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = cookiesFileURL
        openPanel.message = UserText.cookieImportSafariRequestPermissionButtonTitle
        openPanel.allowedFileTypes = ["binarycookie"]
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

    static private var historyFileURL: URL {
        let applicationSupport = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let path = applicationSupport.appendingPathComponent("Safari")

        return path.appendingPathComponent("History.db")
    }

    static private var cookiesFileURL: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let path = library.appendingPathComponent("Containers/com.apple.Safari/Data/Library/Cookies")

        return path.appendingPathComponent("Cookies.binarycookies")
    }

    private let bookmarkImporter: BookmarkImporter
    private let historyImporter: HistoryImporter
    private let cookieImporter: CookieImporter

    init(bookmarkImporter: BookmarkImporter, historyImporter: HistoryImporter, cookieImporter: CookieImporter) {
        self.bookmarkImporter = bookmarkImporter
        self.historyImporter = historyImporter
        self.cookieImporter = cookieImporter
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
                    summary.bookmarksResult = try bookmarkImporter.importBookmarks(bookmarks, source: .safari)
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

        if types.contains(.history) {
            let historyReader = SafariHistoryReader(safariHistoryDatabaseURL: Self.historyFileURL)
            let historyResult = historyReader.readHistory()

            switch historyResult {
            case .success(let visits):
                summary.historyResult = historyImporter.importHistory(visits)
            case .failure(let error):
                completion(.failure(.history(error)))
            }
        }

        if types.contains(.cookies) {
            let cookieReader = SafariCookiesReader(safariCookiesFileURL: Self.cookiesFileURL)
            let cookiesResult = cookieReader.readCookies()

            switch cookiesResult {
            case .success(let cookies):
                if cookies.isEmpty {
                    completion(.success(summary))
                } else {
                    let s = summary
                    Task { @MainActor in
                        var summary = s
                        summary.cookiesResult = await cookieImporter.importCookies(cookies)
                        completion(.success(summary))
                    }
                }
            case .failure(let error):
                completion(.failure(.cookies(error)))
            }
        } else {
            completion(.success(summary))
        }
    }

}
