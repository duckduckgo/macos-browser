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

    init(loginImporter: LoginImporter) {
        self.loginImporter = loginImporter
    }

    func importableTypes() -> [DataImport.DataType] {
        return [.logins]
    }

    // swiftlint:disable cyclomatic_complexity
    func importData(types: [DataImport.DataType], completion: @escaping (Result<[DataImport.Summary], DataImportError>) -> Void) {
        guard let defaultPath = defaultFirefoxProfilePath() else {
            completion(.failure(.cannotReadFile))
            return
        }

        let loginReader = FirefoxLoginReader(firefoxProfileURL: defaultPath, primaryPassword: self.primaryPassword)
        let loginResult = loginReader.readLogins()

        switch loginResult {
        case .success(let logins):
            do {
                let summary = try loginImporter.importLogins(logins)
                completion(.success([summary]))
            } catch {
                completion(.failure(.cannotAccessSecureVault))
            }
        case .failure(let error):

            switch error {
            case .couldNotFindProfile:
                let alert = NSAlert.failureAlert(message: "Could not find profile")
                alert.runModal()
            case .couldNotGetDecryptionKey:
                let alert = NSAlert.failureAlert(message: "Could not get decryption key")
                alert.runModal()
            case .couldNotReadLoginsFile:
                let alert = NSAlert.failureAlert(message: "Could not read logins.json")
                alert.runModal()
            case .decryptionFailed:
                let alert = NSAlert.failureAlert(message: "Decryption failed")
                alert.runModal()
            case .databaseAccessFailed:
                let alert = NSAlert.failureAlert(message: "Firefox database access failed")
                alert.runModal()
            default: break
            }

            switch error {
            case .requiresPrimaryPassword:
                completion(.failure(.needsLoginPrimaryPassword))
            default:
                completion(.failure(.browserNeedsToBeClosed))
            }
        }
    }

    private func defaultFirefoxProfilePath() -> URL? {
        guard let potentialProfiles = try? FileManager.default.contentsOfDirectory(atPath: profilesDirectoryURL().path) else {
            return nil
        }

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
