//
//  PseudoFolder.swift
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

import AppKit
import Foundation

final class PseudoFolder: Equatable {

    static let favorites = PseudoFolder(id: UUID().uuidString, name: UserText.favorites, icon: .favoriteFilledBorder)
    static let bookmarks = PseudoFolder(id: UUID().uuidString, name: UserText.bookmarks, icon: .bookmarksFolder)

    let id: String
    let name: String
    let icon: NSImage

    /// Represents the total bookmarks or favorites, used when displaying in an NSOutlineView.
    var count: Int = 0

    // PseudoFolder instances aren't created directly, they are provided via the static values above.
    private init(id: String, name: String, icon: NSImage) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    static func == (lhs: PseudoFolder, rhs: PseudoFolder) -> Bool {
        return lhs.id == rhs.id
    }

}
