//
//  CSVLoginImporter.swift
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

final class CSVLoginImporter {

    struct LoginCredential {
        let url: String
        let username: String
        let password: String

        init(url: String, username: String, password: String) {
            self.url = url
            self.username = username
            self.password = password
        }

        init?(row: [String]) {
            if row.count == 3 {
                self.init(url: row[0], username: row[1], password: row[2])
            }

            return nil
        }
    }

    enum CSVParseError: Error {
        case cannotReadFile
        case invalidFormat
    }

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func readLoginEntries() -> Result<[LoginCredential], CSVParseError> {
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return .failure(.cannotReadFile)
        }

        let parsed = fileContents.parseAlt()
        let loginCredentials: [LoginCredential] = parsed.compactMap(LoginCredential.init(row:))

        return .success(loginCredentials)
    }

}
