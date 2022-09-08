//
//  FirefoxDataImporter.swift
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

final class FirefoxDataImporter: DataImporter {

    var primaryPassword: String?

    let loginImporter: LoginImporter
    let bookmarkImporter: BookmarkImporter
    let historyImporter: HistoryImporter
    let cookieImporter: CookieImporter

    init(loginImporter: LoginImporter, bookmarkImporter: BookmarkImporter, historyImporter: HistoryImporter, cookieImporter: CookieImporter) {
        self.loginImporter = loginImporter
        self.bookmarkImporter = bookmarkImporter
        self.historyImporter = historyImporter
        self.cookieImporter = cookieImporter
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.logins, .bookmarks, .history, .cookies]
    }

    // swiftlint:disable:next cyclomatic_complexity
    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (Result<DataImport.Summary, DataImportError>) -> Void) {
        guard let firefoxProfileURL = profile?.profileURL ?? defaultFirefoxProfilePath() else {
            completion(.failure(.generic(.cannotReadFile)))
            return
        }

        var summary = DataImport.Summary()

        if types.contains(.logins) {
            let loginReader = FirefoxLoginReader(firefoxProfileURL: firefoxProfileURL, primaryPassword: self.primaryPassword)
            let loginResult = loginReader.readLogins(dataFormat: nil)

            switch loginResult {
            case .success(let logins):
                do {
                    summary.loginsResult = .completed(try loginImporter.importLogins(logins))
                } catch {
                    completion(.failure(.logins(.cannotAccessSecureVault)))
                }
            case .failure(let error):
                switch error {
                case .requiresPrimaryPassword: completion(.failure(.logins(.needsLoginPrimaryPassword)))
                case .databaseAccessFailed: completion(.failure(.logins(DataImportError.ImportErrorType.databaseAccessFailed)))
                case .couldNotFindProfile: completion(.failure(.logins(.couldNotFindProfile)))
                case .couldNotGetDecryptionKey: completion(.failure(.logins(.couldNotGetDecryptionKey)))
                case .couldNotReadLoginsFile: completion(.failure(.logins(.cannotReadFile)))
                case .decryptionFailed: completion(.failure(.logins(.cannotDecryptFile)))
                case .failedToTemporarilyCopyFile: completion(.failure(.logins(.failedToTemporarilyCopyFile)))
                }

                return
            }
        }

        if types.contains(.bookmarks) {
            let bookmarkReader = FirefoxBookmarksReader(firefoxDataDirectoryURL: firefoxProfileURL)
            let bookmarkResult = bookmarkReader.readBookmarks()

            switch bookmarkResult {
            case .success(let bookmarks):
                do {
                    summary.bookmarksResult = try bookmarkImporter.importBookmarks(bookmarks, source: .firefox)
                } catch {
                    guard let error = error as? FirefoxBookmarksReader.ImportError else {
                        completion(.failure(.bookmarks(.unexpectedBookmarksDatabaseFormat)))
                        return
                    }
                    
                    completion(.failure(.bookmarks(error)))
                    return
                }
            case .failure(let error):
                completion(.failure(.bookmarks(error)))
                return
            }
        }

        if types.contains(.history) {
            let historyReader = FirefoxHistoryReader(firefoxDataDirectoryURL: firefoxProfileURL)
            let historyResult = historyReader.readHistory()

            switch historyResult {
            case .success(let visits):
                summary.historyResult = historyImporter.importHistory(visits)
            case .failure(let error):
                completion(.failure(.history(error)))
            }
        }

        if types.contains(.cookies) {
            let cookieReader = FirefoxCookiesReader(firefoxDataDirectoryURL: firefoxProfileURL)
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
    
    func importData(types: [DataImport.DataType], from profile: DataImport.BrowserProfile?) async -> Result<DataImport.Summary, DataImportError> {
        return await withCheckedContinuation { continuation in
            importData(types: types, from: profile) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func defaultFirefoxProfilePath() -> URL? {
        guard let potentialProfiles = try? FileManager.default.contentsOfDirectory(atPath: profilesDirectoryURL().path) else {
            return nil
        }

        // This is the value used by Firefox in production releases. Use it by default, if no profile is selected.
        let profiles = potentialProfiles.filter { $0.hasSuffix(".default-release") }

        guard let selectedProfile = profiles.first else {
            return nil
        }

        return profilesDirectoryURL().appendingPathComponent(selectedProfile)
    }

    private func profilesDirectoryURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupportURL.appendingPathComponent("Firefox/Profiles")
    }

}
