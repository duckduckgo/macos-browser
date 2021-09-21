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

enum SecureVaultItem: Equatable, Identifiable {

    case account(SecureVaultModels.WebsiteAccount)
    case identity(SecureVaultModels.Identity)
    case note(SecureVaultModels.Note)

    var websiteAccount: SecureVaultModels.WebsiteAccount? {
        switch self {
        case .account(let account):
            return account
        default:
            return nil
        }
    }

    // Used as a unique identifier for SwiftUI
    var id: String? {
        switch self {
        case .account(let account):
            if let id = account.id {
                return "account-\(id)"
            } else {
                return "account-unsaved"
            }
        case .identity(let identity):
            if let id = identity.id {
                return "identity-\(id)"
            } else {
                return "identity-unsaved"
            }
        case .note(let note):
            if let id = note.id {
                return "note-\(id)"
            } else {
                return "note-unsaved"
            }
        }
    }

    var secureVaultID: Int64? {
        switch self {
        case .account(let account):
            return account.id
        case .identity(let identity):
            return identity.id
        case .note(let note):
            return note.id
        }
    }

    var title: String? {
        switch self {
        case .account(let account):
            return account.title
        case .identity(let identity):
            return identity.title
        case .note(let note):
            return note.title
        }
    }

    func item(matches filter: String) -> Bool {
        switch self {
        case .account(let account):
            return account.domain.lowercased().contains(filter) ||
                account.username.lowercased().contains(filter) ||
                account.title?.lowercased().contains(filter) ?? false
        case .identity(let identity):
            return identity.title.localizedCaseInsensitiveContains(filter)
        case .note(let note):
            return note.title.localizedCaseInsensitiveContains(filter)
        }
    }

    var displayTitle: String {
        switch self {
        case .account(let account):
            return ((account.title ?? "").isEmpty == true ? account.domain.dropWWW() : account.title) ?? ""
        case .identity(let identity):
            return identity.title
        case .note(let note):
            return note.title
        }
    }

    var displaySubtitle: String {
        switch self {
        case .account(let account):
            return account.username
        case .identity(let identity):
            let formatter = PersonNameComponentsFormatter()

            var nameComponents = PersonNameComponents()
            nameComponents.givenName = identity.firstName
            nameComponents.middleName = identity.middleName
            nameComponents.familyName = identity.lastName

            return formatter.string(from: nameComponents)
        case .note(let note):
            return note.text.truncated(length: 100)
        }
    }

    static func == (lhs: SecureVaultItem, rhs: SecureVaultItem) -> Bool {
        switch (lhs, rhs) {
        case (.account(let account1), .account(let account2)):
            return account1.id == account2.id
        case (.identity(let identity1), .identity(let identity2)):
            return identity1.id == identity2.id
        case (.note(let note1), .note(let note2)):
            return note1.id == note2.id
        default:
            return false
        }
    }

}

//// Using generic "item list" term as eventually this will be more than just accounts.
///
/// Could maybe even abstract a bunch of this code to be more generic re-usable styled list for use elsewhere.
final class PasswordManagementItemListModel: ObservableObject {

    var items = [SecureVaultItem]() {
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

    func selected(item: SecureVaultItem) {
        let previous = selected
        selected = item
        onItemSelected(previous, item)
    }

    func select(item: SecureVaultItem) {
        selected = displayedAccounts.first(where: { $0 == item })
    }

    func updateAccount(_ account: SecureVaultItem) {
        var accounts = displayedAccounts

        guard let index = accounts.firstIndex(where: {
            $0 == account
        }) else { return }

        accounts[index] = account
        displayedAccounts = accounts
    }

    func refresh() {
        let filter = self.filter.lowercased()

        if filter.isEmpty {
            displayedAccounts = items
        } else {
            let filter = filter.lowercased()
            displayedAccounts = items.filter { $0.item(matches: filter) }
        }
    }

    func selectFirst() {
        selected = nil
        if let selectedAccount = displayedAccounts.first {
            selected(item: selectedAccount)
        }
    }

    func clearSelection() {
        selected = nil
    }

}
