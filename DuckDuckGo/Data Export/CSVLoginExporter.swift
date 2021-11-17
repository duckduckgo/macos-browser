//
//  CSVLoginExporter.swift
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
import BrowserServicesKit

final class CSVLoginExporter {

    enum CSVLoginExportError: Error {
        case failedToEncodeLogins
    }

    private let secureVault: SecureVault
    private let fileStore: FileStore

    init(secureVault: SecureVault, fileStore: FileStore = FileManager.default) {
        self.secureVault = secureVault
        self.fileStore = fileStore
    }

    func exportVaultLogins(to url: URL) throws {
        guard let accounts = try? secureVault.accounts() else {
            return
        }

        var credentialsToExport: [SecureVaultModels.WebsiteCredentials] = []

        for account in accounts {
            guard let accountID = account.id else {
                continue
            }

            if let credentials = try? secureVault.websiteCredentialsFor(accountId: accountID) {
                credentialsToExport.append(credentials)
            }
        }

        try save(credentials: credentialsToExport, to: url)
    }

    private func save(credentials: [SecureVaultModels.WebsiteCredentials], to url: URL) throws {
        let credentialsAsCSVRows: [String] = credentials.compactMap { credential in
            let title = credential.account.title ?? ""
            let domain = credential.account.domain
            let username = credential.account.username
            let password = credential.password.utf8String() ?? ""

            // Ensure that exported passwords escape any quotes they contain
            let escapedPassword = password.replacingOccurrences(of: "\"", with: "\\\"")

            return "\"\(title)\",\"\(domain)\",\"\(username)\",\"\(escapedPassword)\""
        }

        let headerRow = ["\"title\",\"url\",\"username\",\"password\""]
        let csvString = (headerRow + credentialsAsCSVRows).joined(separator: "\n")

        if let stringData = csvString.data(using: .utf8) {
            _ = fileStore.persist(stringData, url: url)
        } else {
            throw CSVLoginExportError.failedToEncodeLogins
        }
    }

}
