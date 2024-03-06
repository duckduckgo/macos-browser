//
//  SecureVaultSorting.swift
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

import AppKit
import Foundation
import SwiftUI

struct SecureVaultSorting: Equatable {

    static let `default` = SecureVaultSorting(category: .allItems, parameter: .title, order: .ascending)

    enum Category: CaseIterable, Identifiable {
        var id: Category { self }

        case allItems
        case logins
        case identities
        case cards

        var title: String {
            switch self {
            case .allItems: return UserText.passwordManagementAllItems
            case .logins: return UserText.passwordManagementLogins
            case .identities: return UserText.passwordManagementIdentities
            case .cards: return UserText.passwordManagementCreditCards
            }
        }

        var image: NSImage? {
            switch self {
            case .allItems: return nil
            case .logins: return .loginGlyph
            case .identities: return .identityGlyph
            case .cards: return .creditCardGlyph
            }
        }

        var backgroundColor: NSColor {
            switch self {
            case .allItems: .secureVaultCategoryDefault
            case .logins: .logins
            case .identities: .identities
            case .cards: .cards
            }
        }

        var foregroundColor: NSColor? {
            switch self {
            case .allItems: return nil // Show white or black depending on system appearance
            case .logins: return .black
            case .identities: return .black
            case .cards: return .white
            }
        }
    }

    enum SortParameter: CaseIterable {
        case title
        case dateModified
        case dateCreated

        var title: String {
            switch self {
            case .title: return UserText.pmSortParameterTitle
            case .dateModified: return UserText.pmSortParameterDateModified
            case .dateCreated: return UserText.pmSortParameterDateCreated
            }
        }
        var type: SortDataType {
            switch self {
            case .title: return .string
            case .dateModified, .dateCreated: return .date
            }
        }
    }

    enum SortOrder: CaseIterable {
        case ascending
        case descending

        func title(for sortDataType: SortDataType) -> String {
            switch sortDataType {
            case .string:
                switch self {
                case .ascending: return UserText.pmSortStringAscending
                case .descending: return UserText.pmSortStringDescending
                }
            case .date:
                switch self {
                case .ascending: return UserText.pmSortDateAscending
                case .descending: return UserText.pmSortDateDescending
                }
            }
        }
    }

    enum SortDataType {
        case string
        case date
    }

    var category: Category
    var parameter: SortParameter
    var order: SortOrder

}
