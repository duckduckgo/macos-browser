//
//  SuggestionViewModel.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import Suggestions

struct SuggestionViewModel: Equatable {

    let isHomePage: Bool
    let suggestion: Suggestion
    let userStringValue: String

    init(isHomePage: Bool, suggestion: Suggestion, userStringValue: String) {
        self.isHomePage = isHomePage
        self.suggestion = suggestion
        self.userStringValue = userStringValue
    }

    // MARK: - Attributed Strings

    static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()

    private static let homePageTableRowViewStandardAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .regular),
        .paragraphStyle: Self.paragraphStyle
    ]

    private static let regularTableRowViewStandardAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .paragraphStyle: Self.paragraphStyle
    ]

    private static let homePageTableRowViewBoldAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .paragraphStyle: Self.paragraphStyle
    ]

    private static let regularTableRowViewBoldAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .bold),
        .paragraphStyle: Self.paragraphStyle
    ]

    var tableRowViewStandardAttributes: [NSAttributedString.Key: Any] {
        isHomePage ? Self.homePageTableRowViewStandardAttributes : Self.regularTableRowViewStandardAttributes
    }

    var tableRowViewBoldAttributes: [NSAttributedString.Key: Any] {
        isHomePage ? Self.homePageTableRowViewBoldAttributes : Self.regularTableRowViewBoldAttributes
    }

    var tableCellViewAttributedString: NSAttributedString {
        var firstPart = ""
        var boldPart = string
        if string.hasPrefix(userStringValue) {
            firstPart = String(string.prefix(userStringValue.count))
            boldPart = String(string.dropFirst(userStringValue.count))
        }

        let attributedString = NSMutableAttributedString(string: firstPart, attributes: tableRowViewStandardAttributes)
        let boldAttributedString = NSAttributedString(string: boldPart, attributes: tableRowViewBoldAttributes)
        attributedString.append(boldAttributedString)

        return attributedString
    }

    var string: String {
        switch suggestion {
        case .phrase(phrase: let phrase):
            return phrase
        case .website(url: let url):
            return url.toString(forUserInput: userStringValue)
        case .historyEntry(title: let title, url: let url, allowedInTopHits: _):
            if url.isDuckDuckGoSearch {
                return url.searchQuery ?? url.toString(forUserInput: userStringValue)
            } else {
                return title ?? url.toString(forUserInput: userStringValue)
            }
        case .bookmark(title: let title, url: _, isFavorite: _, allowedInTopHits: _),
             .internalPage(title: let title, url: _),
             .openTab(title: let title, url: _):
            return title
        case .unknown(value: let value):
            return value
        }
    }

    var title: String? {
        switch suggestion {
        case .phrase,
             .website,
             .unknown:
            return nil
        case .historyEntry(title: let title, url: let url, allowedInTopHits: _):
            if url.isDuckDuckGoSearch {
                return url.searchQuery
            } else {
                return title
            }
        case .bookmark(title: let title, url: _, isFavorite: _, allowedInTopHits: _),
             .internalPage(title: let title, url: _),
             .openTab(title: let title, url: _):
            return title
        }
    }

    var autocompletionString: String {
        switch suggestion {
        case .historyEntry(title: _, url: let url, allowedInTopHits: _),
             .bookmark(title: _, url: let url, isFavorite: _, allowedInTopHits: _):

            let userStringValue = self.userStringValue.lowercased()
            let urlString = url.toString(forUserInput: userStringValue)
            if !urlString.hasPrefix(userStringValue),
               let title = self.title,
               title.lowercased().hasPrefix(userStringValue) {
                return title
            }

            return urlString

        default:
            return self.string
        }
    }

    var suffix: String {
        switch suggestion {
        // for punycoded urls display real url as a suffix
        case .website(url: let url) where url.toString(forUserInput: userStringValue, decodePunycode: false) != self.string:
            return " – " + url.toString(decodePunycode: false, dropScheme: true, dropTrailingSlash: true)

        case .phrase, .unknown, .website:
            return ""
        case .openTab(title: _, url: let url) where url.isDuckURLScheme:
            return " – " + UserText.duckDuckGo
        case .openTab(title: _, url: let url) where url.isDuckDuckGoSearch:
            return " – " + UserText.duckDuckGoSearchSuffix
        case .historyEntry(title: _, url: let url, allowedInTopHits: _),
             .bookmark(title: _, url: let url, isFavorite: _, allowedInTopHits: _),
             .openTab(title: _, url: let url):
            if url.isDuckDuckGoSearch {
                return " – \(UserText.searchDuckDuckGoSuffix)"
            } else {
                return " – " + url.toString(decodePunycode: true,
                                              dropScheme: true,
                                              dropTrailingSlash: true)
            }
        case .internalPage:
            return " – " + UserText.duckDuckGo
        }
    }

    // MARK: - Icon

    var icon: NSImage? {
        switch suggestion {
        case .phrase:
            return .search
        case .website:
            return .web
        case .historyEntry:
            return .historySuggestion
        case .bookmark(title: _, url: _, isFavorite: false, allowedInTopHits: _):
            return .bookmarkSuggestion
        case .bookmark(title: _, url: _, isFavorite: true, allowedInTopHits: _):
            return .favoritedBookmarkSuggestion
        case .unknown:
            return .web
        case .internalPage(title: _, url: let url) where url == .bookmarks,
             .openTab(title: _, url: let url) where url == .bookmarks:
            return .bookmarksFolder
        case .internalPage(title: _, url: let url) where url.isSettingsURL,
             .openTab(title: _, url: let url) where url.isSettingsURL:
            return .settingsMulticolor16
        case .internalPage(title: _, url: let url):
            guard url == URL(string: StartupPreferences.shared.formattedCustomHomePageURL) else { return nil }
            return .home16
        case .openTab:
            return .openTabSuggestion
        }
    }

}
