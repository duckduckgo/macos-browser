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

enum SecureVaultItem {
    case account(SecureVaultModels.WebsiteAccount)

    var websiteAccount: SecureVaultModels.WebsiteAccount {
        switch self {
        case .account(let account):
            return account
        }
    }

    var id: Int64? {
        switch self {
        case .account(let account):
            return account.id
        }
    }

    var title: String? {
        switch self {
        case .account(let account):
            return account.title
        }
    }

    func item(matches filter: String) -> Bool {
        switch self {
        case .account(let account):
            return account.domain.lowercased().contains(filter) ||
                account.username.lowercased().contains(filter) ||
                account.title?.lowercased().contains(filter) ?? false
        }
    }

    var displayTitle: String {
        switch self {
        case .account(let account):
            return ((account.title ?? "").isEmpty == true ? account.domain.dropWWW() : account.title) ?? ""
        }
    }

    var displaySubtitle: String {
        switch self {
        case .account(let account):
            return account.username
        }
    }
}

//// Using generic "item list" term as eventually this will be more than just accounts.
///
/// Could maybe even abstract a bunch of this code to be more generic re-usable styled list for use elsewhere.
final class PasswordManagementItemListModel: ObservableObject {

    var accounts = [SecureVaultItem]() {
        didSet {
            refresh()
        }
    }

    var filter: String = "" {
        didSet {
            refresh()
        }
    }

    @Published private(set) var displayedAccounts = [SecureVaultItem]()
    @Published private(set) var selected: SecureVaultItem?

    private var onItemSelected: (_ old: SecureVaultItem?, _ new: SecureVaultItem) -> Void

    init(onItemSelected: @escaping (_ old: SecureVaultItem?, _ new: SecureVaultItem) -> Void) {
        self.onItemSelected = onItemSelected
    }

    func select(item: SecureVaultItem) {
        let previous = selected
        selected = item
        onItemSelected(previous, item)
    }

    func selectItem(with id: Int64) {
        selected = displayedAccounts.first(where: { $0.id == id })
    }

    func updateAccount(_ account: SecureVaultItem) {
        var accounts = displayedAccounts

        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            displayedAccounts = accounts
        }
    }

    func refresh() {
        let filter = self.filter.lowercased()

        if filter.isEmpty {
            displayedAccounts = accounts
        } else {
            let filter = filter.lowercased()
            displayedAccounts = accounts.filter { $0.item(matches: filter) }
        }
    }

    func selectFirst() {
        selected = nil
        if let selected = displayedAccounts.first {
            select(item: selected)
        }
    }

    func clearSelection() {
        selected = nil
    }

}
