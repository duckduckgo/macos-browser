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

    private enum ImporterError: Error {
        case duplicate
    }

    func importLogins(_ logins: [ImportedLoginCredential], progressCallback: @escaping (Int) throws -> Void) throws -> DataImport.DataTypeSummary {
        let vault = try AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared)

        var successful: [String] = []
        var duplicates: [String] = []
        var failed: [String] = []

        let encryptionKey = try vault.getEncryptionKey()
        let hashingSalt = try vault.getHashingSalt()

        let accounts: [SecureVaultModels.WebsiteAccount]

        if let results = try? vault.accounts() {
            accounts = results
        } else {
            accounts = .init()
        }

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
                    if let signature = try vault.encryptPassword(for: credentials, key: encryptionKey, salt: hashingSalt).account.signature {
                        let isDuplicate = accounts.contains {
                            $0.isDuplicateOf(accountToBeImported: account, signatureOfAccountToBeImported: signature)
                        }
                        if isDuplicate {
                            throw ImporterError.duplicate
                        }
                    }
                    _ = try vault.storeWebsiteCredentials(credentials, in: database, encryptedUsing: encryptionKey, hashedUsing: hashingSalt)
                    successful.append(importSummaryValue)
                } catch {
                    if case .duplicateRecord = error as? SecureStorageError {
                        duplicates.append(importSummaryValue)
                    } else if case .duplicate = error as? ImporterError {
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

extension SecureVaultModels.WebsiteAccount {
    /*
     Rules
     username: is a duplicate if:
     it's an exact match
     one entry has a value and the other entry doesn't, it's not a duplicate
     password: is a duplicate if:
     it's an exact match
     one entry has a value and the other entry doesn't, it's not a duplicate
     url: is a duplicate if:
     if the cleaned* version of the URL is an exact match, it's a duplicate
     notes: is a duplicate if:
     it's an exact match
     the stored entry has a value and the import entry doesn't
     title: is a duplicate if:
     it's an exact match
     the stored entry has a value and the import entry doesn't
     */
    func isDuplicateOf(accountToBeImported: Self, signatureOfAccountToBeImported: String) -> Bool {
        guard signature == signatureOfAccountToBeImported else {
            return false
        }
        guard username == accountToBeImported.username || accountToBeImported.username.isNilOrEmpty else {
            return false
        }
        guard domain == accountToBeImported.domain || accountToBeImported.domain.isNilOrEmpty else {
            return false
        }
        guard notes == accountToBeImported.notes || accountToBeImported.notes.isNilOrEmpty else {
            return false
        }
        guard title == accountToBeImported.title || accountToBeImported.title.isNilOrEmpty else {
            return false
        }
        return true
    }
}
