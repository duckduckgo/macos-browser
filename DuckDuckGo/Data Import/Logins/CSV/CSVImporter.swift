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

    func importableTypes() -> [DataImport.DataType] {
        if fileURL.pathExtension == "csv" {
            return [.logins]
        } else {
            return []
        }
    }

    func importData(types: [DataImport.DataType], completion: (Result<[DataImport.Summary], DataImportError>) -> Void) {
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            completion(.failure(.cannotReadFile))
            return
        }

        let loginCredentials = Self.extractLogins(from: fileContents)

        do {
            let loginImportSummary = try loginImporter.importLogins(loginCredentials)
            let dataImportSummary = [
                DataImport.Summary(type: .logins, summaryDetail: loginImportSummary)
            ]

            completion(.success(dataImportSummary))
        } catch {
            completion(.failure(.cannotAccessSecureVault))
        }
    }

    private static func extractLogins(from fileContents: String) -> [LoginCredential] {
        let parsed = CSVParser.parse(string: fileContents)
        let loginCredentials: [LoginCredential] = parsed.compactMap(LoginCredential.init(row:))

        return loginCredentials
    }

}
