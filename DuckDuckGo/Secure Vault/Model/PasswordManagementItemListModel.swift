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

import Foundation
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
            if let accountId = account.id {
                return Int64(accountId)
            }
            return nil
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
    
    var created: Date {
        switch self {
        case .account(let account):
            return account.created
        case .card(let card):
            return card.created
        case .identity(let identity):
            return identity.created
        case .note(let note):
            return note.created
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
            return ((account.title ?? "").isEmpty == true ? account.domain.droppingWwwPrefix() : account.title) ?? ""
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
    
    var firstCharacter: String {
        let defaultFirstCharacter = "#"

        guard let character = self.displayTitle.first else {
            return defaultFirstCharacter
        }
        
        if character.isLetter {
            return character.uppercased()
        } else {
            return defaultFirstCharacter
        }
    }
    
    var category: SecureVaultSorting.Category {
        switch self {
        case .account: return .logins
        case .card: return .cards
        case .identity: return .identities
        case .note: return .allItems
        }
    }
    
    func matches(category: SecureVaultSorting.Category) -> Bool {
        if category == .allItems {
            return true
        }
        
        return self.category == category
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
    let passwordManagerCoordinator: PasswordManagerCoordinator
    
    enum EmptyState {
        /// Displays nothing for the empty state. Used when data is still loading, or when filtering the All Items list.
        case none
        
        /// Displays an empty state which prompts the user to import data. Used when the user has no items of any type.
        case noData
        case logins
        case identities
        case notes
        case creditCards
    }

    static let personNameComponentsFormatter: PersonNameComponentsFormatter = {
        let nameFormatter = PersonNameComponentsFormatter()
        nameFormatter.style = .medium

        return nameFormatter
    }()

    var filter: String = "" {
        didSet {
            updateFilteredData()

            // Only select the first item if the filter has actually changed
            if oldValue != filter {
                selectFirst()
            }
        }
    }

    private var items = [SecureVaultItem]() {
        didSet {
            updateFilteredData()
            calculateEmptyState()
        }
    }

    @Published var sortDescriptor = SecureVaultSorting.default {
        didSet {
            guard oldValue != sortDescriptor else {
                return
            }
            
            updateFilteredData()
            selectFirst()
        }
    }

    @Published private(set) var displayedItems = [PasswordManagementListSection]() {
        didSet {
            calculateEmptyState()
        }
    }

    @Published private(set) var selected: SecureVaultItem?
    @Published var externalPasswordManagerSelected: Bool = false {
        didSet {
            if externalPasswordManagerSelected {
                selected = nil
            }
        }
    }
    @Published private(set) var emptyState: EmptyState = .none
    @Published var canChangeCategory: Bool = true

    private var onItemSelected: (_ old: SecureVaultItem?, _ new: SecureVaultItem?) -> Void

    init(passwordManagerCoordinator: PasswordManagerCoordinator, onItemSelected: @escaping (_ old: SecureVaultItem?, _ new: SecureVaultItem?) -> Void) {
        self.onItemSelected = onItemSelected
        self.passwordManagerCoordinator = passwordManagerCoordinator
    }

    func update(items: [SecureVaultItem]) {
        self.items = items.sorted()
    }

    func selected(item: SecureVaultItem?, notify: Bool = true) {
        // If selecting an item that does not exist in the current category, then swap to that category first.
        if let item = item, sortDescriptor.category != .allItems, item.category != sortDescriptor.category {
            sortDescriptor.category = item.category
        }
        
        let previous = selected
        selected = item
        
        if selected != nil {
            externalPasswordManagerSelected = false
        }
        
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
    
    func selectLoginWithDomainOrFirst(domain: String, notify: Bool = true) {
        for section in displayedItems {
            if let account = section.items.first(where: { $0.websiteAccount?.domain == domain }) {
                selected(item: account, notify: notify)
                return
            }
        }
        
        selectFirst()
    }

    func update(item: SecureVaultItem) {
        if let index = items.firstIndex(of: item) {
            items[index] = item
        }

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

    func updateFilteredData() {
        let filter = self.filter.lowercased()
        var itemsByCategory = items.filter { $0.matches(category: sortDescriptor.category) }

        if !filter.isEmpty {
            itemsByCategory = itemsByCategory.filter { $0.item(matches: filter) }
        }

        if displayedItems.isEmpty && items.isEmpty {
            return
        }

        switch sortDescriptor.parameter {
        case .title:
            displayedItems = PasswordManagementListSection.sections(with: itemsByCategory, by: \.firstCharacter, order: sortDescriptor.order)
        case .dateCreated:
            displayedItems = PasswordManagementListSection.sections(with: itemsByCategory, by: \.created, order: sortDescriptor.order)
        case .dateModified:
            displayedItems = PasswordManagementListSection.sections(with: itemsByCategory, by: \.lastUpdated, order: sortDescriptor.order)
        }
    }

    func selectFirst() {
        selected = nil

        if passwordManagerCoordinator.isEnabled && (sortDescriptor.category == .allItems || sortDescriptor.category == .logins) {
            externalPasswordManagerSelected = true
        } else if let firstSection = displayedItems.first, let selectedItem = firstSection.items.first {
            selected(item: selectedItem)
        } else {
            selected(item: nil)
        }
    }
    
    func clear() {
        update(items: [])
        filter = ""
        clearSelection()
        
        // Setting items to an empty array will typically show the No Data empty state, but this call is used when
        // the popover is closed so instead there should be no empty state.
        emptyState = .none
    }

    func clearSelection() {
        selected = nil
    }

    private func sortIntoSectionsByItemType(_ items: [SecureVaultItem]) -> [PasswordManagementListSection] {
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

        var sections = [PasswordManagementListSection]()

        if !accounts.isEmpty { sections.append(PasswordManagementListSection(title: "Logins", items: accounts)) }
        if !cards.isEmpty { sections.append(PasswordManagementListSection(title: "Credit Cards", items: cards)) }
        if !identities.isEmpty { sections.append(PasswordManagementListSection(title: "Identities", items: identities)) }
        if !notes.isEmpty { sections.append(PasswordManagementListSection(title: "Notes", items: notes)) }

        return sections
    }
    
    private func calculateEmptyState() {
        guard !items.isEmpty else {
            emptyState = .noData
            return
        }
        
        guard displayedItems.isEmpty else {
            emptyState = .none
            return
        }
        
        switch sortDescriptor.category {
        case .allItems: emptyState = .none
        case .cards: emptyState = .creditCards
        case .logins: emptyState = .logins
        case .identities: emptyState = .identities
        }
    }

}
