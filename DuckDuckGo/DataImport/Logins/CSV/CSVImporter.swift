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

import Common
import Foundation

final class CSVImporter: DataImporter {

    struct ColumnPositions {

        private enum Regex {
            // should end with "login" or "username"
            static let username = regex("(?:^|\\b|\\s|_)(?:login|username)$", .caseInsensitive)
            // should end with "password" or "pwd"
            static let password = regex("(?:^|\\b|\\s|_)(?:password|pwd)$", .caseInsensitive)
            // should end with "name" or "title"
            static let title = regex("(?:^|\\b|\\s|_)(?:name|title)$", .caseInsensitive)
            // should end with "url", "uri"
            static let url = regex("(?:^|\\b|\\s|_)(?:url|uri)$", .caseInsensitive)
            // should end with "notes" or "note"
            static let notes = regex("(?:^|\\b|\\s|_)(?:notes|note)$", .caseInsensitive)
        }

        static let rowFormatWithTitle = ColumnPositions(titleIndex: 0, urlIndex: 1, usernameIndex: 2, passwordIndex: 3)
        static let rowFormatWithoutTitle = ColumnPositions(titleIndex: nil, urlIndex: 0, usernameIndex: 1, passwordIndex: 2)

        let maximumIndex: Int

        let titleIndex: Int?
        let urlIndex: Int?

        let usernameIndex: Int
        let passwordIndex: Int

        let notesIndex: Int?

        let isZohoVault: Bool

        init(titleIndex: Int?, urlIndex: Int?, usernameIndex: Int, passwordIndex: Int, notesIndex: Int? = nil, isZohoVault: Bool = false) {
            self.titleIndex = titleIndex
            self.urlIndex = urlIndex
            self.usernameIndex = usernameIndex
            self.passwordIndex = passwordIndex
            self.notesIndex = notesIndex
            self.maximumIndex = max(titleIndex ?? -1, urlIndex ?? -1, usernameIndex, passwordIndex, notesIndex ?? -1)
            self.isZohoVault = isZohoVault
        }

        private enum Format {
            case general
            case zohoGeneral
            case zohoVault
        }

        init?(csv: [[String]]) {
            guard csv.count > 1,
                  csv[1].count >= 3 else { return nil }
            var headerRow = csv[0]

            var format = Format.general

            let usernameIndex: Int
            if let idx = headerRow.firstIndex(where: { value in
                Regex.username.matches(in: value, range: value.fullRange).isEmpty == false
            }) {
                usernameIndex = idx
                headerRow[usernameIndex] = ""

            // Zoho
            } else if headerRow.first == "Password Name" {
                if let idx = csv[1].firstIndex(of: "SecretData") {
                    format = .zohoVault
                    usernameIndex = idx
                } else if csv[1].count == 7 {
                    format = .zohoGeneral
                    usernameIndex = 5
                } else {
                    return nil
                }
            } else {
                return nil
            }

            let passwordIndex: Int
            switch format {
            case .general:
                guard let idx = headerRow
                    .firstIndex(where: { !Regex.password.matches(in: $0, range: $0.fullRange).isEmpty }) else { return nil }
                passwordIndex = idx
                headerRow[passwordIndex] = ""

            case .zohoGeneral:
                passwordIndex = usernameIndex + 1
            case .zohoVault:
                passwordIndex = usernameIndex
            }

            let titleIndex = headerRow.firstIndex(where: { !Regex.title.matches(in: $0, range: $0.fullRange).isEmpty })
            titleIndex.map { headerRow[$0] = "" }

            let urlIndex = headerRow.firstIndex(where: { !Regex.url.matches(in: $0, range: $0.fullRange).isEmpty })
            urlIndex.map { headerRow[$0] = "" }

            let notesIndex = headerRow.firstIndex(where: { !Regex.notes.matches(in: $0, range: $0.fullRange).isEmpty })

            self.init(titleIndex: titleIndex,
                      urlIndex: urlIndex,
                      usernameIndex: usernameIndex,
                      passwordIndex: passwordIndex,
                      notesIndex: notesIndex,
                      isZohoVault: format == .zohoVault)
        }

        init?(source: DataImport.Source) {
            switch source {
            case .onePassword7, .onePassword8:
                self.init(titleIndex: 3, urlIndex: 5, usernameIndex: 6, passwordIndex: 2)
            case .lastPass, .firefox, .edge, .chrome, .chromium, .coccoc, .brave, .opera, .operaGX,
                 .safari, .safariTechnologyPreview, .tor, .vivaldi, .yandex, .csv, .bookmarksHTML, .bitwarden:
                return nil
            }
        }

    }

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case cannotReadFile
        }

        var action: DataImportAction { .logins }
        let type: OperationType
        let underlyingError: Error?
    }

    private let fileURL: URL
    private let loginImporter: LoginImporter
    private let defaultColumnPositions: ColumnPositions?

    init(fileURL: URL, loginImporter: LoginImporter, defaultColumnPositions: ColumnPositions?) {
        self.fileURL = fileURL
        self.loginImporter = loginImporter
        self.defaultColumnPositions = defaultColumnPositions
    }

    static func totalValidLogins(in fileURL: URL, defaultColumnPositions: ColumnPositions?) -> Int {
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else { return 0 }

        let logins = extractLogins(from: fileContents, defaultColumnPositions: defaultColumnPositions) ?? []

        return logins.count
    }

    static func extractLogins(from fileContents: String,
                              defaultColumnPositions: ColumnPositions? = nil) -> [ImportedLoginCredential]? {
        guard let parsed = try? CSVParser().parse(string: fileContents) else { return nil }

        let columnPositions: ColumnPositions?
        var startRow = 0
        if let autodetected = ColumnPositions(csv: parsed) {
            columnPositions = autodetected
            startRow = 1
        } else {
            columnPositions = defaultColumnPositions
        }

        guard parsed.indices.contains(startRow) else { return [] } // no data

        let result = parsed[startRow...].compactMap(columnPositions.read)

        guard !result.isEmpty else {
            if parsed.filter({ !$0.isEmpty }).isEmpty {
                return [] // no data
            } else {
                return nil // error: could not parse data
            }
        }

        return result
    }

    var importableTypes: [DataImport.DataType] {
        return [.passwords]
    }

    func importData(types: Set<DataImport.DataType>) -> DataImportTask {
        .detachedWithProgress { updateProgress in
            let result = self.importLoginsSync()
            return [.passwords: result]
        }
    }

    func importLoginsSync() -> DataImportResult<DataImport.DataTypeSummary> {
        let fileContents: String
        do {
            fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return .failure(ImportError(type: .cannotReadFile, underlyingError: error))
        }

        do {
            let loginCredentials = try Self.extractLogins(from: fileContents, defaultColumnPositions: defaultColumnPositions) ?? {
                throw LoginImporterError(error: nil, type: .malformedCSV)
            }()
            let summary = try loginImporter.importLogins(loginCredentials)

            return .success(summary)

        } catch let error as DataImportError {
            return .failure(error)
        } catch {
            return .failure(LoginImporterError(error: error))
        }
    }

}

extension ImportedLoginCredential {

    // Some browsers will export credentials with a header row. To detect this, the URL field on the first parsed row is checked whether it passes
    // the data detector test. If it doesn't, it's assumed to be a header row.
    fileprivate var isHeaderRow: Bool {
        let types: NSTextCheckingResult.CheckingType = [.link]

        guard let detector = try? NSDataDetector(types: types.rawValue),
              let url, !url.isEmpty else { return false }

        if detector.numberOfMatches(in: url, options: [], range: url.fullRange) > 0 {
            return false
        }

        return true
    }

}

extension CSVImporter.ColumnPositions {

    func read(_ row: [String]) -> ImportedLoginCredential? {
        let username: String
        let password: String

        if isZohoVault {
            // cell contents:
            // SecretType:Web Account
            // User Name:username
            // Password:password
            guard let lines = row[safe: usernameIndex]?.components(separatedBy: "\n"),
                  let usernameLine = lines.first(where: { $0.hasPrefix("User Name:") }),
                  let passwordLine = lines.first(where: { $0.hasPrefix("Password:") }) else { return nil }

            username = usernameLine.dropping(prefix: "User Name:")
            password = passwordLine.dropping(prefix: "Password:")

        } else if let user = row[safe: usernameIndex],
                  let pass = row[safe: passwordIndex] {

            username = user
            password = pass
        } else {
            return nil
        }

        return ImportedLoginCredential(title: row[safe: titleIndex ?? -1],
                                       url: row[safe: urlIndex ?? -1],
                                       username: username,
                                       password: password,
                                       notes: row[safe: notesIndex ?? -1])
    }

}

extension CSVImporter.ColumnPositions? {

    func read(_ row: [String]) -> ImportedLoginCredential? {
        let columnPositions = self ?? [
            .rowFormatWithTitle,
            .rowFormatWithoutTitle
        ].first(where: {
            row.count > $0.maximumIndex
        })

        return columnPositions?.read(row)
    }

}
