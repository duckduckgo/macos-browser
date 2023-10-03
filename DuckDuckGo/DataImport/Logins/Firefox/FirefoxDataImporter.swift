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
import SecureStorage

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

    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (DataImportResult<DataImport.Summary>) -> Void) {
        let result = importData(types: types, from: profile)
        completion(result)
    }

    private func importData(types: [DataImport.DataType], from profile: DataImport.BrowserProfile?) -> DataImportResult<DataImport.Summary> {
        let firefoxProfileURL: URL
        do {
            firefoxProfileURL = try profile?.profileURL ?? Self.defaultFirefoxProfilePath() ?? {
                throw LoginImporterError(source: .firefox, error: nil, type: .defaultFirefoxProfilePathNotFound)
            }()
        } catch let error as LoginImporterError {
            return .failure(error)
        } catch {
            return .failure(LoginImporterError(source: .firefox, error: error, type: .defaultFirefoxProfilePathNotFound))
        }

        var summary = DataImport.Summary()

        if types.contains(.logins) {
            let loginReader = FirefoxLoginReader(firefoxProfileURL: firefoxProfileURL, primaryPassword: self.primaryPassword)
            let loginResult = loginReader.readLogins(dataFormat: nil)

            switch loginResult {
            case .success(let logins):
                do {
                    let result = try loginImporter.importLogins(logins)
                    summary.loginsResult = .completed(result)
                } catch {
                    return .failure(LoginImporterError(source: .firefox, error: error))
                }
            case .failure(let error):
                return .failure(error)
            }
        }

        if types.contains(.bookmarks) {
            let bookmarkReader = FirefoxBookmarksReader(firefoxDataDirectoryURL: firefoxProfileURL)
            let bookmarkResult = bookmarkReader.readBookmarks()

            importFavicons(from: firefoxProfileURL)

            switch bookmarkResult {
            case .success(let bookmarks):
                summary.bookmarksResult = bookmarkImporter.importBookmarks(bookmarks, source: .thirdPartyBrowser(.firefox))
            case .failure(let error):
                return .failure(error)
            }
        }

        return .success(summary)
    }

    @MainActor(unsafe)
    private func importFavicons(from firefoxProfileURL: URL) {
        let faviconsReader = FirefoxFaviconsReader(firefoxDataDirectoryURL: firefoxProfileURL)
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

    static func loginDatabaseRequiresPrimaryPassword(profileURL: URL?) -> Bool {
        guard let firefoxProfileURL = try? profileURL ?? defaultFirefoxProfilePath() else {
            return false
        }

        let loginReader = FirefoxLoginReader(firefoxProfileURL: firefoxProfileURL, primaryPassword: nil)
        let loginResult = loginReader.readLogins(dataFormat: nil)

        switch loginResult {
        case .failure(let failure as FirefoxLoginReader.ImportError):
            return failure.type == .requiresPrimaryPassword
        default:
            return false
        }
    }

    private static func defaultFirefoxProfilePath() throws -> URL? {
        let profilesDirectory = URL.nonSandboxApplicationSupportDirectoryURL.appendingPathComponent("Firefox/Profiles")
        let potentialProfiles = try FileManager.default.contentsOfDirectory(atPath: profilesDirectory.path)

        // This is the value used by Firefox in production releases. Use it by default, if no profile is selected.
        let profiles = potentialProfiles.filter { $0.hasSuffix(".default-release") }

        guard let selectedProfile = profiles.first else {
            return nil
        }

        return profilesDirectory.appendingPathComponent(selectedProfile)
    }

}
