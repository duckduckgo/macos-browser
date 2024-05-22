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

    func importLogins(_ logins: [ImportedLoginCredential], progressCallback: @escaping (Int) throws -> Void) throws -> DataImport.DataTypeSummary {
        let vault = try AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared)

        var successful: [String] = []
        var duplicates: [String] = []
        var failed: [String] = []

        let encryptionKey = try vault.getEncryptionKey()
        let hashingSalt = try vault.getHashingSalt()

        try vault.inDatabaseTransaction { database in
            for (idx, login) in logins.enumerated() {
                let title = login.title
                let account = SecureVaultModels.WebsiteAccount(title: title, username: login.username, domain: login.url, notes: login.notes)
                let credentials = SecureVaultModels.WebsiteCredentials(account: account, password: login.password.data(using: .utf8)!)
                let importSummaryValue: String

                if let title = account.title {
                    importSummaryValue = "\(title): \(credentials.account.domain ?? "") (\(credentials.account.username ?? ""))"
                } else {
                    importSummaryValue = "\(credentials.account.domain ?? "") (\(credentials.account.username ?? ""))"
                }

                do {
                    _ = try vault.storeWebsiteCredentials(credentials, in: database, encryptedUsing: encryptionKey, hashedUsing: hashingSalt)
                    successful.append(importSummaryValue)
                } catch {
                    if case .duplicateRecord = error as? SecureStorageError {
                        duplicates.append(importSummaryValue)
                    } else {
                        failed.append(importSummaryValue)
                    }
                }

                try progressCallback(idx + 1)
            }
        }

        if successful.count > 0 {
            NotificationCenter.default.post(name: .autofillSaveEvent, object: nil, userInfo: nil)
        }

        return .init(successful: successful.count, duplicate: duplicates.count, failed: failed.count)
    }

}
