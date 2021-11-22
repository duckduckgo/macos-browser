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
    case card(SecureVaultModels.CreditCard)
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
        case .card(let card):
            return card.id
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
        case .card(let card):
            return card.title
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
        case .card(let card):
            return card.lastUpdated
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
        case .card(let card):
            return card.title.localizedCaseInsensitiveContains(filter)
        case .identity(let identity):
            return identity.title.localizedCaseInsensitiveContains(filter)
        case .note(let note):
            return note.title.localizedCaseInsensitiveContains(filter) ||
                note.text.localizedCaseInsensitiveContains(filter) ||
                (note.associatedDomain?.localizedCaseInsensitiveContains(filter) ?? false)
        }
    }

    var displayTitle: String {
        switch self {
        case .account(let account):
            return ((account.title ?? "").isEmpty == true ? account.domain.dropWWW() : account.title) ?? ""
        case .card(let card):
            return card.title
        case .identity(let identity):
            return identity.title
        case .note(let note):
            let title = note.displayTitle
            return title ?? UserText.pmEmptyNote
        }
    }

    var displaySubtitle: String {
        switch self {
        case .account(let account):
            return account.username
        case .card(let creditCard):
            return creditCard.displayName
        case .identity(let identity):
            var nameComponents = PersonNameComponents()
            nameComponents.givenName = identity.firstName
            nameComponents.middleName = identity.middleName
            nameComponents.familyName = identity.lastName

            return PasswordManagementItemListModel.personNameComponentsFormatter.string(from: nameComponents)
        case .note(let note):
            let subtitle = note.displaySubtitle
            return subtitle
        }
    }

    static func == (lhs: SecureVaultItem, rhs: SecureVaultItem) -> Bool {
        switch (lhs, rhs) {
        case (.account(let account1), .account(let account2)):
            return account1.id == account2.id
        case (.card(let card1), .card(let card2)):
            return card1.id == card2.id
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
        case cards([SecureVaultItem])
        case notes([SecureVaultItem])
        case identities([SecureVaultItem])

        var title: String {
            switch self {
            case .accounts: return "Logins"
            case .cards: return "Credit Cards"
            case .notes: return "Notes"
            case .identities: return "Identities"
            }
        }

        var items: [SecureVaultItem] {
            switch self {
            case .accounts(let items): return items
            case .cards(let items): return items
            case .notes(let items): return items
            case .identities(let items): return items
            }
        }

        func withUpdatedItems(_ newItems: [SecureVaultItem]) -> ListSection {
            switch self {
            case .accounts: return .accounts(newItems)
            case .cards: return .cards(newItems)
            case .notes: return .notes(newItems)
            case .identities: return .identities(newItems)
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

            // Only select the first item if the filter has actually changed
            if oldValue != filter {
                selectFirst()
            }
        }
    }

    private var items = [SecureVaultItem]() {
        didSet {
            refresh()
        }
    }

    @Published private(set) var displayedItems = [ListSection]()
    @Published private(set) var selected: SecureVaultItem?

    private var onItemSelected: (_ old: SecureVaultItem?, _ new: SecureVaultItem?) -> Void

    init(onItemSelected: @escaping (_ old: SecureVaultItem?, _ new: SecureVaultItem?) -> Void) {
        self.onItemSelected = onItemSelected
    }

    func update(items: [SecureVaultItem]) {
        self.items = items.sorted()
    }

    func selected(item: SecureVaultItem?, notify: Bool = true) {
        let previous = selected
        selected = item
        if notify {
            onItemSelected(previous, item)
        }
    }

    func select(item: SecureVaultItem, notify: Bool = true) {
        for section in displayedItems {
            if let first = section.items.first(where: { $0 == item }) {
                selected(item: first, notify: notify)
            }
        }
    }

    func update(item: SecureVaultItem) {
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
        } else {
            selected(item: nil)
        }
    }

    func clearSelection() {
        selected = nil
    }

    private func sortIntoSections(_ items: [SecureVaultItem]) -> [ListSection] {
        var accounts = [SecureVaultItem]()
        var cards = [SecureVaultItem]()
        var identities = [SecureVaultItem]()
        var notes = [SecureVaultItem]()

        for item in items {
            switch item {
            case .account:
                accounts.append(item)
            case .card:
                cards.append(item)
            case .note:
                notes.append(item)
            case .identity:
                identities.append(item)
            }
        }

        var sections = [ListSection]()

        if !accounts.isEmpty { sections.append(.accounts(accounts)) }
        if !cards.isEmpty { sections.append(.cards(cards)) }
        if !identities.isEmpty { sections.append(.identities(identities)) }
        if !notes.isEmpty { sections.append(.notes(notes)) }

        return sections
    }

}
