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

    private let loginImporter: LoginImporter
    private let bookmarkImporter: BookmarkImporter
    private let faviconManager: FaviconManagement

    init(loginImporter: LoginImporter, bookmarkImporter: BookmarkImporter, faviconManager: FaviconManagement) {
        self.loginImporter = loginImporter
        self.bookmarkImporter = bookmarkImporter
        self.faviconManager = faviconManager
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.logins, .bookmarks]
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
                case .couldNotFindLoginsFile: completion(.failure(.logins(.cannotFindFile)))
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

            importFavicons(from: firefoxProfileURL)

            switch bookmarkResult {
            case .success(let bookmarks):
                do {
                    summary.bookmarksResult = try bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(.firefox))
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

        completion(.success(summary))
    }
    
    func importData(types: [DataImport.DataType], from profile: DataImport.BrowserProfile?) async -> Result<DataImport.Summary, DataImportError> {
        return await withCheckedContinuation { continuation in
            importData(types: types, from: profile) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    private func importFavicons(from firefoxProfileURL: URL) {
        let faviconsReader = FirefoxFaviconsReader(firefoxDataDirectoryURL: firefoxProfileURL)
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
            Pixel.fire(.faviconImportFailed(source: .firefox))
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
