//
//  MockSecureVault.swift
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

final class MockSecureVault: SecureVault {

    var storedAccounts: [SecureVaultModels.WebsiteAccount] = []
    var storedCredentials: [Int64: SecureVaultModels.WebsiteCredentials] = [:]

    func authWith(password: Data) throws -> SecureVault {
        return self
    }

    func resetL2Password(oldPassword: Data?, newPassword: Data) throws {}

    func accounts() throws -> [SecureVaultModels.WebsiteAccount] {
        return storedAccounts
    }

    func accountsFor(domain: String) throws -> [SecureVaultModels.WebsiteAccount] {
        return storedAccounts.filter { $0.domain == domain }
    }

    func websiteCredentialsFor(accountId: Int64) throws -> SecureVaultModels.WebsiteCredentials? {
        return storedCredentials[accountId]
    }

    func storeWebsiteCredentials(_ credentials: SecureVaultModels.WebsiteCredentials) throws -> Int64 {
        let accountID = credentials.account.id!
        storedCredentials[accountID] = credentials

        return accountID
    }

    func deleteWebsiteCredentialsFor(accountId: Int64) throws {
        storedCredentials[accountId] = nil
    }

}
