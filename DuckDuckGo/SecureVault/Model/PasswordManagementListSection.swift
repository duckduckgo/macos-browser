//
//  PasswordManagementListSection.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

struct PasswordManagementListSection {

    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    struct DateMetadata: Equatable, Hashable, Comparable {
        static func < (lhs: PasswordManagementListSection.DateMetadata, rhs: PasswordManagementListSection.DateMetadata) -> Bool {
            if lhs.year != rhs.year {
                return lhs.year < rhs.year
            } else {
                return (lhs.month, lhs.year) < (rhs.month, rhs.year)
            }
        }

        static let unknown = DateMetadata(title: "#", month: 0, year: 0)

        let title: String
        let month: Int
        let year: Int
    }

    let title: String
    let items: [SecureVaultItem]

    static let tld: TLD = ContentBlocking.shared.tld
    static let autofillUrlSort: AutofillUrlSort = AutofillDomainNameUrlSort()
    static let autofillDefaultKey = "#"

    func withUpdatedItems(_ newItems: [SecureVaultItem]) -> PasswordManagementListSection {
        return PasswordManagementListSection(title: title, items: newItems)
    }

    static func sections(with items: [SecureVaultItem],
                         by keyPath: KeyPath<SecureVaultItem, String>,
                         order: SecureVaultSorting.SortOrder) -> [PasswordManagementListSection] {

        let itemsByFirstCharacter: [String: [SecureVaultItem]] = Dictionary(grouping: items) { $0[keyPath: keyPath] }

        let sortedKeys = itemsByFirstCharacter.keys.sorted(by: caseInsensitiveCompare(for: order))

        return sortedKeys.map { key in
            var itemsInSection = itemsByFirstCharacter[key] ?? []
            itemsInSection.sort { lhs, rhs in
                return titleCompare(lhs, rhs, order)
            }
            return PasswordManagementListSection(title: key, items: itemsInSection)
        }
    }

    static func sectionsByTLD(with items: [SecureVaultItem],
                              order: SecureVaultSorting.SortOrder) -> [PasswordManagementListSection] {

        let itemsByFirstCharacter: [String: [SecureVaultItem]] = items.reduce(into: [String: [SecureVaultItem]]()) { result, vaultItem in
            var key: String = autofillDefaultKey
            if vaultItem.websiteAccount == nil {
                key = vaultItem.firstCharacter
            } else {
                if let acc = vaultItem.websiteAccount,
                   let firstChar = autofillUrlSort.firstCharacterForGrouping(acc, tld: tld),
                   let deDistinctionedChar = String(firstChar).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).first,
                   deDistinctionedChar.isLetter {
                    key = String(deDistinctionedChar.uppercased())
                }
            }
            return result[key, default: []].append(vaultItem)
        }

        let sortedKeys = itemsByFirstCharacter.keys.sorted(by: caseInsensitiveCompare(for: order))

        return sortedKeys.map { key in
            var itemsInSection = itemsByFirstCharacter[key] ?? []
            itemsInSection.sort { lhs, rhs in
                return titleAndTLDCompare(lhs, rhs, order)
            }
            return PasswordManagementListSection(title: key, items: itemsInSection)
        }
    }

    static func sections(with items: [SecureVaultItem],
                         by keyPath: KeyPath<SecureVaultItem, Date>,
                         order: SecureVaultSorting.SortOrder) -> [PasswordManagementListSection] {
        let itemsByDateMetadata: [DateMetadata: [SecureVaultItem]] = Dictionary(grouping: items) {
            let date = $0[keyPath: keyPath]

            guard let month = date.components.month, let year = date.components.year else {
                return DateMetadata.unknown
            }

            return DateMetadata(title: Self.dateFormatter.string(from: date), month: month, year: year)
        }

        let sortedKeys = switch order {
        case .ascending: itemsByDateMetadata.keys.sorted(by: (>))
        case .descending: itemsByDateMetadata.keys.sorted(by: (<))
        }

        return sortedKeys.map { key in
            var itemsInSection = itemsByDateMetadata[key, default: []]
            switch order {
            case .ascending:
                itemsInSection.sort(by: { $0[keyPath: keyPath] > $1[keyPath: keyPath] })
            case .descending:
                itemsInSection.sort(by: { $0[keyPath: keyPath] < $1[keyPath: keyPath] })
            }
            return PasswordManagementListSection(title: key.title, items: itemsInSection)
        }
    }

    private static func caseInsensitiveCompare(for order: SecureVaultSorting.SortOrder) -> (String, String) -> Bool {
        switch order {
        case .ascending:
            return { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .descending:
            return { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
        }
    }

    private static func titleCompare(_ lhs: SecureVaultItem, _ rhs: SecureVaultItem, _ order: SecureVaultSorting.SortOrder) -> Bool {
        switch order {
        case .ascending:
            return { lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending }()
        case .descending:
            return { lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedDescending }()
        }
    }

    private static func titleAndTLDCompare(_ lhs: SecureVaultItem, _ rhs: SecureVaultItem, _ order: SecureVaultSorting.SortOrder) -> Bool {
        guard let lhsAccount = lhs.websiteAccount, let rhsAccount = rhs.websiteAccount else {
            return false
        }
        switch order {
        case .ascending:
            return { autofillUrlSort.compareAccountsForSortingAutofill(lhs: lhsAccount, rhs: rhsAccount, tld: tld) == .orderedAscending }()
        case .descending:
            return { autofillUrlSort.compareAccountsForSortingAutofill(lhs: lhsAccount, rhs: rhsAccount, tld: tld) == .orderedDescending }()
        }
    }

}
