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
import PixelKit

final class CSVLoginExporter {

    enum CSVLoginExportError: Error {
        case failedToEncodeLogins
    }

    private let secureVault: any AutofillSecureVault
    private let fileStore: FileStore

    init(secureVault: any AutofillSecureVault, fileStore: FileStore = FileManager.default) {
        self.secureVault = secureVault
        self.fileStore = fileStore
    }

    func exportVaultLogins(to url: URL) throws {
        var credentialsToExport: [SecureVaultModels.WebsiteCredentials] = []

        do {
            let accounts = try secureVault.accounts()

            for account in accounts {
                guard let accountID = account.id, let accountIDInt = Int64(accountID) else {
                    continue
                }

                if let credentials = try secureVault.websiteCredentialsFor(accountId: accountIDInt) {
                    credentialsToExport.append(credentials)
                }
            }
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.secureVaultError(error: error)))
            throw error
        }

        try save(credentials: credentialsToExport, to: url)
    }

    private func save(credentials: [SecureVaultModels.WebsiteCredentials], to url: URL) throws {
        let credentialsAsCSVRows: [String] = credentials.compactMap { credential in
            let title = credential.account.title ?? ""
            let domain = credential.account.domain ?? ""
            let username = credential.account.username ?? ""
            let password = credential.password?.utf8String() ?? ""

            // Ensure that exported passwords escape any quotes they contain
            let escapedPassword = password.replacingOccurrences(of: "\"", with: "\\\"")

            return "\"\(title)\",\"\(domain)\",\"\(username)\",\"\(escapedPassword)\""
        }

        let headerRow = ["\"title\",\"url\",\"username\",\"password\""]
        let csvString = (headerRow + credentialsAsCSVRows).joined(separator: "\n")

        let stringData = csvString.utf8data
        _ = fileStore.persist(stringData, url: url)
    }

}
