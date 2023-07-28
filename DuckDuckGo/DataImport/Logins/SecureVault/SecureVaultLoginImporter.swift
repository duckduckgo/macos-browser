//
//  SecureVaultLoginImporter.swift
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
import SecureStorage

final class SecureVaultLoginImporter: LoginImporter {

    private let secureVault: any AutofillSecureVault

    init(secureVault: any AutofillSecureVault) {
        self.secureVault = secureVault
    }

    func importLogins(_ logins: [ImportedLoginCredential]) throws -> DataImport.CompletedLoginsResult {
        let vault = try AutofillSecureVaultFactory.makeVault(errorReporter: SecureVaultErrorReporter.shared)

        var successful: [String] = []
        var duplicates: [String] = []
        var failed: [String] = []

        for login in logins {
            let title = login.title
            let account = SecureVaultModels.WebsiteAccount(title: title, username: login.username, domain: login.url)
            let credentials = SecureVaultModels.WebsiteCredentials(account: account, password: login.password.data(using: .utf8)!)
            let importSummaryValue: String

            if let title = account.title {
                importSummaryValue = "\(title): \(credentials.account.domain) (\(credentials.account.username))"
            } else {
                importSummaryValue = "\(credentials.account.domain) (\(credentials.account.username))"
            }

            do {
                _ = try vault.storeWebsiteCredentials(credentials)
                successful.append(importSummaryValue)
            } catch {
                if case .duplicateRecord = error as? SecureStorageError {
                    duplicates.append(importSummaryValue)
                } else {
                    failed.append(importSummaryValue)
                }
            }
        }

        return .init(successfulImports: successful, duplicateImports: duplicates, failedImports: failed)
    }

}
