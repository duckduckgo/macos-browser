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

enum SecureVaultItem: Equatable, Identifiable, Comparable {

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
    var id: String {
        return String(describing: self)
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

    var lastUpdated: Date {
        switch self {
        case .account(let account):
            return account.lastUpdated
        case .identity(let identity):
            return identity.lastUpdated
        case .note(let note):
            return note.lastUpdated
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
            var nameComponents = PersonNameComponents()
            nameComponents.givenName = identity.firstName
            nameComponents.middleName = identity.middleName
            nameComponents.familyName = identity.lastName

            return PasswordManagementItemListModel.personNameComponentsFormatter.string(from: nameComponents)
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

    static func < (lhs: SecureVaultItem, rhs: SecureVaultItem) -> Bool {
        if let lhsTitle = lhs.title, let rhsTitle = rhs.title {
            return lhsTitle < rhsTitle
        }

        return lhs.lastUpdated < rhs.lastUpdated
    }

}

//// Using generic "item list" term as eventually this will be more than just accounts.
///
/// Could maybe even abstract a bunch of this code to be more generic re-usable styled list for use elsewhere.
final class PasswordManagementItemListModel: ObservableObject {

    enum ListSection {
        case accounts([SecureVaultItem])
        case notes([SecureVaultItem])
        case identities([SecureVaultItem])

        var title: String {
            switch self {
            case .accounts:
                return "Accounts"
            case .notes:
                return "Notes"
            case .identities:
                return "Identities"
            }
        }

        var items: [SecureVaultItem] {
            switch self {
            case .accounts(let items):
                return items
            case .notes(let items):
                return items
            case .identities(let items):
                return items
            }
        }

        func withUpdatedItems(_ newItems: [SecureVaultItem]) -> ListSection {
            switch self {
            case .accounts:
                return .accounts(newItems)
            case .notes:
                return .notes(newItems)
            case .identities:
                return .identities(newItems)
            }
        }

    }

    static let personNameComponentsFormatter: PersonNameComponentsFormatter = {
        let nameFormatter = PersonNameComponentsFormatter()
        nameFormatter.style = .medium

        return nameFormatter
    }()

    var filter: String = "" {
        didSet {
            refresh()
        }
    }

    private var items = [SecureVaultItem]() {
        didSet {
            refresh()
        }
    }

    @Published private(set) var displayedItems = [ListSection]()
    @Published private(set) var selected: SecureVaultItem?

    private var onItemSelected: (_ old: SecureVaultItem?, _ new: SecureVaultItem) -> Void

    init(onItemSelected: @escaping (_ old: SecureVaultItem?, _ new: SecureVaultItem) -> Void) {
        self.onItemSelected = onItemSelected
    }

    func update(items: [SecureVaultItem]) {
        self.items = items.sorted()
    }

    func selected(item: SecureVaultItem) {
        let previous = selected
        selected = item
        onItemSelected(previous, item)
    }

    func select(item: SecureVaultItem) {
        for section in displayedItems {
            if let first = section.items.first(where: { $0 == item }) {
                selected = first
            }
        }
    }

    func updateAccount(_ item: SecureVaultItem) {
        var sections = displayedItems

        guard let sectionIndex = sections.firstIndex(where: {
            $0.items.contains(item)
        }) else { return }

        let updatedSection = displayedItems[sectionIndex]
        var updatedSectionItems = updatedSection.items

        guard let updatedItemIndex = updatedSectionItems.firstIndex(where: {
            $0 == item
        }) else { return }

        updatedSectionItems[updatedItemIndex] = item
        sections[sectionIndex] = updatedSection.withUpdatedItems(updatedSectionItems)

        displayedItems = sections
    }

    func refresh() {
        let filter = self.filter.lowercased()

        if filter.isEmpty {
            displayedItems = sortIntoSections(items)
        } else {
            let filter = filter.lowercased()
            let filteredItems = items.filter { $0.item(matches: filter) }

            displayedItems = sortIntoSections(filteredItems)
        }
    }

    func selectFirst() {
        selected = nil
        if let firstSection = displayedItems.first, let selectedItem = firstSection.items.first {
            selected(item: selectedItem)
        }
    }

    func clearSelection() {
        selected = nil
    }

    private func sortIntoSections(_ items: [SecureVaultItem]) -> [ListSection] {
        var accounts = [SecureVaultItem]()
        var notes = [SecureVaultItem]()
        var identities = [SecureVaultItem]()

        for item in items {
            switch item {
            case .account:
                accounts.append(item)
            case .note:
                notes.append(item)
            case .identity:
                identities.append(item)
            }
        }

        return [
            .accounts(accounts),
            .identities(identities),
            .notes(notes)
        ]
    }

}
