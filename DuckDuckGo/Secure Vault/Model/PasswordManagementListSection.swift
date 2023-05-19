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

struct PasswordManagementListSection {

    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    struct DateMetadata: Equatable, Hashable, Comparable {
        static func < (lhs: PasswordManagementListSection.DateMetadata, rhs: PasswordManagementListSection.DateMetadata) -> Bool {
            return (lhs.month, lhs.year) < (rhs.month, rhs.year)
        }

        static let unknown = DateMetadata(title: "#", month: 0, year: 0)

        let title: String
        let month: Int
        let year: Int
    }

    let title: String
    let items: [SecureVaultItem]

    func withUpdatedItems(_ newItems: [SecureVaultItem]) -> PasswordManagementListSection {
        return PasswordManagementListSection(title: title, items: newItems)
    }

    static func sections(with items: [SecureVaultItem],
                         by keyPath: KeyPath<SecureVaultItem, String>,
                         order: SecureVaultSorting.SortOrder) -> [PasswordManagementListSection] {

        let itemsByFirstCharacter: [String: [SecureVaultItem]] = Dictionary(grouping: items) { $0[keyPath: keyPath] }
        let sortFunction: (String, String) -> Bool = {
            switch order {
            case .ascending:
                return { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            case .descending:
                return { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
            }
        }()
        let sortedKeys = itemsByFirstCharacter.keys.sorted(by: sortFunction)

        return sortedKeys.map { key in
            var itemsInSection = itemsByFirstCharacter[key] ?? []
            itemsInSection.sort { lhs, rhs in sortFunction(lhs.displayTitle, rhs.displayTitle) }
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

        let metadataSortFunction: (DateMetadata, DateMetadata) -> Bool = order == .ascending ? (>) : (<)
        let dateSortFunction: (Date, Date) -> Bool = order == .ascending ? (>) : (<)
        let sortedKeys = itemsByDateMetadata.keys.sorted(by: metadataSortFunction)

        return sortedKeys.map { key in
            var itemsInSection = itemsByDateMetadata[key] ?? []
            itemsInSection.sort { lhs, rhs in dateSortFunction(lhs[keyPath: keyPath], rhs[keyPath: keyPath]) }
            return PasswordManagementListSection(title: key.title, items: itemsInSection)
        }
    }

}
