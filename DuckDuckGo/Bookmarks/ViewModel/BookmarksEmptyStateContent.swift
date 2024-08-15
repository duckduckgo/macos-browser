//
//  BookmarksEmptyStateContent.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

enum BookmarksEmptyStateContent {
    case noBookmarks
    case noSearchResults

    static var titleAccessibilityIdentifier: String {
        "BookmarksEmptyStateContent.emptyStateTitle"
    }

    static var descriptionAccessibilityIdentifier: String {
        "BookmarksEmptyStateContent.emptyStateMessage"
    }

    static var imageAccessibilityIdentifier: String {
        "BookmarksEmptyStateContent.emptyStateImageView"
    }

    var title: String {
        switch self {
        case .noBookmarks: return UserText.bookmarksEmptyStateTitle
        case .noSearchResults: return UserText.bookmarksEmptySearchResultStateTitle
        }
    }

    var description: String {
        switch self {
        case .noBookmarks: return UserText.bookmarksEmptyStateMessage
        case .noSearchResults: return UserText.bookmarksEmptySearchResultStateMessage
        }
    }

    var image: NSImage {
        switch self {
        case .noBookmarks: return .bookmarksEmpty
        case .noSearchResults: return .bookmarkEmptySearch
        }
    }

    var shouldHideImportButton: Bool {
        switch self {
        case .noBookmarks: return false
        case .noSearchResults: return true
        }
    }
}
