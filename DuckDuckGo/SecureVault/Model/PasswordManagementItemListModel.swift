//
//  PasswordManagementItemListModel.swift
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

import Combine
import BrowserServicesKit

//// Using generic "item list" term as eventually this will be more than just accounts.
///
/// Could maybe even abstract a bunch of this code to be more generic re-usable styled list for use elsewhere.
final class PasswordManagementItemListModel: ObservableObject {

    var accounts: [SecureVaultModels.WebsiteAccount]

    @Published private(set) var displayedAccounts: [SecureVaultModels.WebsiteAccount]
    @Published private(set) var selected: SecureVaultModels.WebsiteAccount?

    var onItemSelected: (_ old: SecureVaultModels.WebsiteAccount?, _ new: SecureVaultModels.WebsiteAccount) -> Void

    init(accounts: [SecureVaultModels.WebsiteAccount],
         onItemSelected: @escaping (_ old: SecureVaultModels.WebsiteAccount?, _ new: SecureVaultModels.WebsiteAccount) -> Void) {

        self.accounts = accounts
        self.displayedAccounts = accounts
        self.onItemSelected = onItemSelected
    }

    func selectAccount(_ account: SecureVaultModels.WebsiteAccount) {
        let previous = selected
        selected = account
        onItemSelected(previous, account)
    }

    func selectAccountWithId(_ id: Int64) {
        selected = displayedAccounts.first(where: { $0.id == id })
    }

    func updateAccount(_ account: SecureVaultModels.WebsiteAccount) {
        var accounts = displayedAccounts
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            displayedAccounts = accounts
        }
    }

    func filterUsing(text: String) {
        if text.isEmpty {
            displayedAccounts = accounts
        } else {
            let filter = text.lowercased()
            displayedAccounts = accounts.filter { $0.domain.lowercased().contains(filter) ||
                $0.username.lowercased().contains(filter) ||
                $0.title?.lowercased().contains(filter) ?? false
            }
        }
    }

    func selectFirst() {
        selected = nil
        if let selected = displayedAccounts.first {
            selectAccount(selected)
        }
    }

    func clearSelection() {
        selected = nil
    }

}
