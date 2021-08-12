//
//  CSVImporter.swift
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

final class CSVImporter: DataImporter {

    struct InferredCredentialColumnPositions {

        let maximumIndex: Int

        let titleIndex: Int?
        let urlIndex: Int
        let usernameIndex: Int
        let passwordIndex: Int

        init(titleIndex: Int?, urlIndex: Int, usernameIndex: Int, passwordIndex: Int, maximumIndex: Int) {
            self.titleIndex = titleIndex
            self.urlIndex = urlIndex
            self.usernameIndex = usernameIndex
            self.passwordIndex = passwordIndex
            self.maximumIndex = maximumIndex
        }

        init?(csvValues: [String]) {
            guard csvValues.count >= 3 else { return nil }

            var titlePosition: Int?
            var urlPosition: Int?
            var usernamePosition: Int?
            var passwordPosition: Int?

            for (index, value) in csvValues.enumerated() {
                switch value.lowercased() {
                case "url": urlPosition = index
                case "username": usernamePosition = index
                case "password": passwordPosition = index
                case "title", "name": titlePosition = index
                default: break
                }
            }

            if let url = urlPosition, let  username = usernamePosition, let password = passwordPosition {
                self.init(titleIndex: titlePosition,
                          urlIndex: url,
                          usernameIndex: username,
                          passwordIndex: password,
                          maximumIndex: csvValues.count - 1)
            } else {
                return nil
            }
        }

    }

    private let fileURL: URL
    private let loginImporter: LoginImporter

    init(fileURL: URL, loginImporter: LoginImporter) {
        self.fileURL = fileURL
        self.loginImporter = loginImporter
    }

    static func totalValidLogins(in fileURL: URL) -> Int {
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return 0
        }

        let logins = extractLogins(from: fileContents)
        return logins.count
    }

    static func extractLogins(from fileContents: String) -> [ImportedLoginCredential] {
        let parsed = CSVParser.parse(string: fileContents)

        if let possibleHeaderRow = parsed.first, let inferredColumnPositions = InferredCredentialColumnPositions(csvValues: possibleHeaderRow) {
            return parsed.dropFirst().compactMap {
                ImportedLoginCredential(row: $0, inferredColumnPositions: inferredColumnPositions)
            }
        } else {
            return parsed.compactMap {
                ImportedLoginCredential(row: $0)
            }
        }
    }

    func importableTypes() -> [DataImport.DataType] {
        if fileURL.pathExtension == "csv" {
            return [.logins]
        } else {
            return []
        }
    }

    // This will change to return an array of DataImport.Summary objects, indicating the status of each import type that was requested.
    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (Result<[DataImport.Summary], DataImportError>) -> Void) {
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            completion(.failure(.cannotReadFile))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let loginCredentials = Self.extractLogins(from: fileContents)

            do {
                let loginImportSummary = try self.loginImporter.importLogins(loginCredentials)
                DispatchQueue.main.async { completion(.success([loginImportSummary])) }
            } catch {
                DispatchQueue.main.async { completion(.failure(.cannotAccessSecureVault)) }
            }
        }
    }

}

extension ImportedLoginCredential {

    // Some browsers will export credentials with a header row. To detect this, the URL field on the first parsed row is checked whether it passes
    // the data detector test. If it doesn't, it's assumed to be a header row.
    fileprivate var isHeaderRow: Bool {
        let types: NSTextCheckingResult.CheckingType = [.link]

        guard let detector = try? NSDataDetector(types: types.rawValue), self.url.count > 0 else {
            return false
        }

        if detector.numberOfMatches(in: self.url,
                                    options: NSRegularExpression.MatchingOptions(rawValue: 0),
                                    range: NSRange(location: 0, length: self.url.count)) > 0 {
            return false
        }

        return true
    }

}
