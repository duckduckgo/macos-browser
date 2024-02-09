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
import BrowserServicesKit

protocol SuggestionViewModelDelegate: AnyObject {

    func suggestionViewModelDidLoadNewIcon(_ suggestionViewModel: SuggestionViewModel)

}

final class SuggestionViewModel {

    let isHomePage: Bool
    let suggestion: Suggestion
    var userStringValue: String

    weak var delegate: SuggestionViewModelDelegate?

    init(isHomePage: Bool, suggestion: Suggestion, userStringValue: String) {
        self.isHomePage = isHomePage
        self.suggestion = suggestion
        self.userStringValue = userStringValue

        loadImageIfNeeded()
    }

    private var loadedImage: NSImage?

    var imageLoadingTask: URLSessionDataTask?

    func loadImageIfNeeded() {
        guard let imageUrl = suggestion.imageUrl else {
            return
        }

        imageLoadingTask?.cancel()
        imageLoadingTask = URLSession.shared.dataTask(with: imageUrl) { [weak self] data, _, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                self.loadedImage = nil
                return
            }
            let image = NSImage(data: data)
            self.loadedImage = image
            DispatchQueue.main.async {
                self.delegate?.suggestionViewModelDidLoadNewIcon(self)
            }
        }
        imageLoadingTask?.resume()
    }

    // MARK: - Attributed Strings

    static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()

    private static let homePageTableRowViewStandardAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .regular),
        .paragraphStyle: paragraphStyle
    ]

    private static let regularTableRowViewStandardAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .paragraphStyle: paragraphStyle
    ]

    private static let homePageTableRowViewBoldAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .paragraphStyle: paragraphStyle
    ]

    private static let regularTableRowViewBoldAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .bold),
        .paragraphStyle: paragraphStyle
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
        case .phrase(phrase: let phrase, imageUrl: _):
            return phrase
        case .website(url: let url):
            return url.toString(forUserInput: userStringValue)
        case .historyEntry(title: let title, url: let url, allowedInTopHits: _):
            if url.isDuckDuckGoSearch {
                return url.searchQuery ?? url.toString(forUserInput: userStringValue)
            } else {
                return title ?? url.toString(forUserInput: userStringValue)
            }
        case .bookmark(title: let title, url: _, isFavorite: _, allowedInTopHits: _):
            return title
        }
    }

    var title: String? {
        switch suggestion {
        case .phrase, .website:
            return nil
        case .historyEntry(title: let title, url: let url, allowedInTopHits: _):
            if url.isDuckDuckGoSearch {
                return url.searchQuery
            } else {
                return title
            }
        case .bookmark(title: let title, url: _, isFavorite: _, allowedInTopHits: _):
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

        case .phrase, .website:
            return ""
        case .historyEntry(title: _, url: let url, allowedInTopHits: _),
             .bookmark(title: _, url: let url, isFavorite: _, allowedInTopHits: _):
            if url.isDuckDuckGoSearch {
                return " – \(UserText.searchDuckDuckGoSuffix)"
            } else {
                return " – " + url.toString(decodePunycode: true,
                                              dropScheme: true,
                                              dropTrailingSlash: true)
            }
        }
    }

    // MARK: - Icon

    static let webImage = NSImage(named: "Web")
    static let searchImage = NSImage(named: "Search")
    static let historyImage = NSImage(named: "HistorySuggestion")
    static let bookmarkImage = NSImage(named: "BookmarkSuggestion")
    static let favoriteImage = NSImage(named: "FavoritedBookmarkSuggestion")

    var icon: NSImage? {
        switch suggestion {
        case .phrase(phrase: _, imageUrl: _):
            if let image = loadedImage {
                return image
            } else {
                return Self.searchImage
            }
        case .website:
            return Self.webImage
        case .historyEntry:
            return Self.historyImage
        case .bookmark(title: _, url: _, isFavorite: false, allowedInTopHits: _):
            return Self.bookmarkImage
        case .bookmark(title: _, url: _, isFavorite: true, allowedInTopHits: _):
            return Self.favoriteImage
        }
    }

}

extension SuggestionViewModel: Equatable {

    static func == (lhs: SuggestionViewModel, rhs: SuggestionViewModel) -> Bool {
        lhs === rhs
    }

}
