//
//  LoginImport.swift
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

struct ImportedLoginCredential: Equatable {

    private enum RowFormatWithTitle: Int {
        case title = 0
        case url
        case username
        case password
    }

    private enum RowFormatWithoutTitle: Int {
        case url = 0
        case username
        case password
    }

    let title: String?
    let url: String
    let username: String
    let password: String

    init(title: String? = nil, url: String, username: String, password: String) {
        self.title = title
        self.url = URL(string: url)?.host ?? url // Try to use the host if possible, as the Secure Vault saves credentials using the host.
        self.username = username
        self.password = password
    }

    init?(row: [String], inferredColumnPositions: CSVImporter.ColumnPositions? = nil) {
        if let inferredPositions = inferredColumnPositions {
            guard row.count > inferredPositions.maximumIndex else { return nil }

            var title: String?

            if let titleIndex = inferredPositions.titleIndex {
                title = row[titleIndex]
            }

            self.init(title: title,
                      url: row[inferredPositions.urlIndex],
                      username: row[inferredPositions.usernameIndex],
                      password: row[inferredPositions.passwordIndex])
        } else if row.count >= 4 {
            self.init(title: row[RowFormatWithTitle.title.rawValue],
                      url: row[RowFormatWithTitle.url.rawValue],
                      username: row[RowFormatWithTitle.username.rawValue],
                      password: row[RowFormatWithTitle.password.rawValue])
        } else if row.count >= 3 {
            self.init(url: row[RowFormatWithoutTitle.url.rawValue],
                      username: row[RowFormatWithoutTitle.username.rawValue],
                      password: row[RowFormatWithoutTitle.password.rawValue])
        } else {
            return nil
        }
    }

}

protocol LoginImporter {

    func importLogins(_ logins: [ImportedLoginCredential]) throws -> DataImport.CompletedLoginsResult

}
