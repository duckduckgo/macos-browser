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

final class CSVLoginExporter: LoginExporter {

    private let secureVault: SecureVault

    init(secureVault: SecureVault) {
        self.secureVault = secureVault
    }

    func exportVaultLogins(to url: URL) {
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

        save(credentials: credentialsToExport, to: url)
    }

    func exportLogins(_ logins: [LoginCredential], toURL url: URL) throws {

    }

    private func save(credentials: [SecureVaultModels.WebsiteCredentials], to url: URL) {
        let credentialsAsCSVRows = credentials.map { "\($0.account.domain),\($0.account.username),\($0.password.utf8String()!)" }
        let finalString = credentialsAsCSVRows.joined(separator: "\n")

        do {
            try finalString.write(toFile: url.path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write string, error: \(error)")
        }
    }

}
