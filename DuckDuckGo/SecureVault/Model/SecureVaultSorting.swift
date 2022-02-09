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

import Foundation
import SwiftUI

struct SecureVaultSorting {
    
    static let `default` = SecureVaultSorting(category: .allItems, parameter: .title, order: .ascending)

    enum Category: String, CaseIterable, Identifiable {
        var id: Category { self }

        case allItems = "All Items"
        case logins = "Logins"
        case identities = "Identities"
        case cards = "Credit Cards"
        case notes = "Notes"
        
        var imageName: String? {
            switch self {
            case .allItems: return nil
            case .logins: return "LoginGlyph"
            case .identities: return "IdentityGlyph"
            case .cards: return "CreditCardGlyph"
            case .notes: return "NoteGlyph"
            }
        }
        
        var categoryColor: Color? {
            switch self {
            case .allItems: return nil
            case .logins: return Color("LoginsColor")
            case .identities: return Color("IdentitiesColor")
            case .cards: return Color("CardsColor")
            case .notes: return Color("NotesColor")
            }
        }
        
        var controlAppearance: NSAppearance.Name {
            switch self {
            case .allItems: return .aqua
            case .logins: return .aqua
            case .identities: return .darkAqua
            case .cards: return .darkAqua
            case .notes: return .aqua
            }
        }
    }
    
    enum SortParameter: String, CaseIterable {
        case title = "Title"
        case dateModified = "Date Modified"
        case dateCreated = "Date Created"
        
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
                case .ascending: return "Alphabetically"
                case .descending: return "Reverse Alphabetically"
                }
            case .date:
                switch self {
                case .ascending: return "Newest First"
                case .descending: return "Oldest First"
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
