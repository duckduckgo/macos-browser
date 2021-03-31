//
//  Suggestion.swift
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

import Foundation

public enum Suggestion: Equatable {
    
    case phrase(phrase: String)
    case website(url: URL)
    case bookmark(title: String, url: URL, isFavorite: Bool)
    case unknown(value: String)

}

extension Suggestion {

    init(bookmark: BookmarkProtocol) {
        self = .bookmark(title: bookmark.title, url: bookmark.url, isFavorite: bookmark.isFavorite)
    }

    static let phraseKey = "phrase"

    init(key: String, value: String) {
        self = key == Self.phraseKey ? .phrase(phrase: value) : .unknown(value: value)
    }

}
