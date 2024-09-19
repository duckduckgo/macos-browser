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
import Common

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
            return account.domain?.lowercased().contains(filter) == true ||
                account.username?.lowercased().contains(filter) == true ||
                account.title?.lowercased().contains(filter) == true
        case .card(let card):
            return card.title.localizedCaseInsensitiveContains(filter)
        case .identity(let identity):
            return identity.title.localizedCaseInsensitiveContains(filter)
        case .note(let note):
            return note.title.localizedCaseInsensitiveContains(filter) ||
                note.text.localizedCaseInsensitiveContains(filter) ||
                (note.associatedDomain?.localizedCaseInsensitiveContains(filter) == true)
        }
    }

    var displayTitle: String {
        switch self {
        case .account(let account):
            return ((account.title ?? "").isEmpty == true ? account.domain : account.title) ?? ""
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
            return account.username ?? ""
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

        return character.isLetter ? character.uppercased() : defaultFirstCharacter
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
    let passwordManagerCoordinator: PasswordManagerCoordinating
    let syncPromoManager: SyncPromoManaging

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

    private var shouldDisplaySyncPromoRow: Bool {
        syncPromoManager.shouldPresentPromoFor(.passwords) &&
        (sortDescriptor.category == .allItems || sortDescriptor.category == .logins) &&
        emptyState == .none &&
        filter.isEmpty
    }

    @Published var sortDescriptor = SecureVaultSorting.default {
        didSet {
            guard oldValue != sortDescriptor else {
                return
            }

            clearSelection()
            updateFilteredData()

            /*
             Note: 
             - The following fixes an long-standing issue where the relevant empty state is not displayed
               while switching autofill types when we have no autofill data.
             - Not an ideal solution, but acceptable until we better unify how we manage Autofill
               state (e.g displayedSections, emptyState)
             */
            if emptyState == .noData {
                calculateEmptyState()
            }

            // Select first item if no previous selection was provided
            if selected == nil {
                selectFirst()
            }
        }
    }

    @Published private(set) var displayedSections = [PasswordManagementListSection]() {
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

    @Published var syncPromoSelected: Bool = false {
        didSet {
            if syncPromoSelected {
                selected = nil
            }
        }
    }

    var emptyStateMessageDescription: String {
        autofillPreferences.isAutoLockEnabled ? UserText.pmEmptyStateDefaultDescription : UserText.pmEmptyStateDefaultDescriptionAutolockOff
    }

    var emptyStateMessageLinkText: String {
        UserText.learnMore
    }

    var emptyStateMessageLinkURL: URL {
        URL.passwordManagerLearnMore
    }

    @Published private(set) var emptyState: EmptyState = .none
    @Published var canChangeCategory: Bool = true

    private var onItemSelected: (_ old: SecureVaultItem?, _ new: SecureVaultItem?) -> Void
    private var onAddItemSelected: (_ category: SecureVaultSorting.Category) -> Void
    private let tld: TLD
    private let autofillPreferences: AutofillPreferencesPersistor
    private let urlMatcher: AutofillDomainNameUrlMatcher
    private static let randomColorsCount = 15

    init(passwordManagerCoordinator: PasswordManagerCoordinating,
         syncPromoManager: SyncPromoManaging,
         urlMatcher: AutofillDomainNameUrlMatcher = AutofillDomainNameUrlMatcher(),
         tld: TLD = ContentBlocking.shared.tld,
         autofillPreferences: AutofillPreferencesPersistor = AutofillPreferences(),
         onItemSelected: @escaping (_ old: SecureVaultItem?, _ new: SecureVaultItem?) -> Void,
         onAddItemSelected: @escaping (_ category: SecureVaultSorting.Category) -> Void) {
        self.onItemSelected = onItemSelected
        self.onAddItemSelected = onAddItemSelected
        self.passwordManagerCoordinator = passwordManagerCoordinator
        self.syncPromoManager = syncPromoManager
        self.urlMatcher = urlMatcher
        self.tld = tld
        self.autofillPreferences = autofillPreferences
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
            syncPromoSelected = false
        }

        if notify {
            onItemSelected(previous, item)
        }
    }

    func select(item: SecureVaultItem, notify: Bool = true) {
        for section in displayedSections {
            if let first = section.items.first(where: { $0 == item }) {
                selected(item: first, notify: notify)
                return
            }
        }
        selectFirst()
    }

    func selectLoginWithDomainOrFirst(domain: String, notify: Bool = true) {
        let websiteAccounts = items
            .compactMap { $0.websiteAccount }

        let matchingAccounts = websiteAccounts.filter { account in
            return urlMatcher.isMatchingForAutofill(
                currentSite: domain,
                savedSite: account.domain ?? "",
                tld: tld
            )
        }

        let bestMatch = matchingAccounts.sortedForDomain(domain, tld: tld, removeDuplicates: true)

        // If there are no matches for autofill, just pick the first item in the list
        if let match = bestMatch.first {

            for section in displayedSections {
                if let account = section.items.first(where: {
                    $0.websiteAccount?.username == match.username &&
                    $0.websiteAccount?.domain == match.domain &&
                    $0.websiteAccount?.signature == match.signature
                }) {
                    selected(item: account, notify: notify)
                    return
                }
            }
        }

        selectFirst()
    }

    func update(item: SecureVaultItem) {
        if let index = items.firstIndex(of: item) {
            items[index] = item
        }

        var sections = displayedSections

        guard let sectionIndex = sections.firstIndex(where: {
            $0.items.contains(item)
        }) else { return }

        let updatedSection = displayedSections[sectionIndex]
        var updatedSectionItems = updatedSection.items

        guard let updatedItemIndex = updatedSectionItems.firstIndex(where: {
            $0 == item
        }) else { return }

        updatedSectionItems[updatedItemIndex] = item
        sections[sectionIndex] = updatedSection.withUpdatedItems(updatedSectionItems)

        displayedSections = sections
    }

    func updateFilteredData() {
        let filter = self.filter.lowercased()
        var itemsByCategory = items.filter { $0.matches(category: sortDescriptor.category) }

        if !filter.isEmpty {
            itemsByCategory = itemsByCategory.filter { $0.item(matches: filter) }
        }

        if displayedSections.isEmpty && items.isEmpty {
            return
        }

        switch sortDescriptor.parameter {
        case .title:
            displayedSections = PasswordManagementListSection.sectionsByTLD(with: itemsByCategory, order: sortDescriptor.order)
        case .dateCreated:
            displayedSections = PasswordManagementListSection.sections(with: itemsByCategory, by: \.created, order: sortDescriptor.order)
        case .dateModified:
            displayedSections = PasswordManagementListSection.sections(with: itemsByCategory, by: \.lastUpdated, order: sortDescriptor.order)
        }
    }

    func selectFirst() {
        selected = nil
        syncPromoSelected = false

        if passwordManagerCoordinator.isEnabled && (sortDescriptor.category == .allItems || sortDescriptor.category == .logins) {
            externalPasswordManagerSelected = true
        } else if shouldDisplaySyncPromoRow {
            syncPromoSelected = true
        } else if let firstSection = displayedSections.first, let selectedItem = firstSection.items.first {
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

        if !accounts.isEmpty { sections.append(PasswordManagementListSection(title: "Passwords", items: accounts)) }
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

        guard displayedSections.isEmpty else {
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

    func tldForAccount(_ account: SecureVaultModels.WebsiteAccount) -> String {
        let name = account.name(tld: tld, autofillDomainNameUrlMatcher: urlMatcher)
        let title = (account.title?.isEmpty == false) ? account.title! : "#"
        return tld.eTLDplus1(name) ?? title
    }

    func onAddItemClickedFor(_ category: SecureVaultSorting.Category) {
        onAddItemSelected(category)
    }

}
