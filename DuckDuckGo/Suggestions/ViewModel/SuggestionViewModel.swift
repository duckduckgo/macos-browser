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

class SuggestionViewModel {

    let suggestion: Suggestion
    let userStringValue: String

    init(suggestion: Suggestion, userStringValue: String) {
        if case .phrase(phrase: let phrase) = suggestion, let url = phrase.url, url.isValid {
            self.suggestion = .website(url: url)
        } else {
            self.suggestion = suggestion
        }
        self.userStringValue = userStringValue
    }

    // MARK: - Attributed Strings

    static let tableRowViewStandardAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .regular)]
    static let tableRowViewBoldAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .bold)]

    var tableCellViewAttributedString: NSAttributedString {
        var firstPart = ""
        var boldPart = string
        if string.hasPrefix(userStringValue) {
            firstPart = String(string.prefix(userStringValue.count))
            boldPart = String(string.dropFirst(userStringValue.count))
        }

        let attributedString = NSMutableAttributedString(string: firstPart, attributes: Self.tableRowViewStandardAttributes)
        let boldAttributedString = NSAttributedString(string: boldPart, attributes: Self.tableRowViewBoldAttributes)
        attributedString.append(boldAttributedString)
        return attributedString
    }

    var string: String {
        switch suggestion {
        case .phrase(phrase: let phrase):
            return phrase
        case .website(url: let url):
            return url.absoluteStringWithoutSchemeAndWWW
        case .unknown(value: let value):
            return value
        }
    }

    // MARK: - Icon

    static let webImage = NSImage(named: "Web")
    static let searchImage = NSImage(named: "Search")

    var icon: NSImage? {
        switch suggestion {
        case .phrase(phrase: _):
            return Self.searchImage
        case .website(url: _):
            return Self.webImage
        case .unknown(value: _):
            return Self.webImage
        }
    }

}

fileprivate extension URL {

    var absoluteStringWithoutSchemeAndWWW: String {
        if let scheme = scheme {
            return absoluteString.dropPrefix(scheme + "://").dropPrefix("www.")
        } else {
            return absoluteString
        }
    }

}
