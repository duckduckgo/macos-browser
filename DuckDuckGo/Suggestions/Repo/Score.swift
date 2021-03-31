//
//  Score.swift
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

import Foundation

typealias Score = Int

extension Score {
    
    init(bookmark: BookmarkProtocol, query: Query, queryTokens: [Query]) {
        // Note: Original scoring algorithm from iOS browser
        var score = bookmark.isFavorite ? 0 : -1
        let title = bookmark.title.lowercased()

        // Exact matches - full query
        if title.starts(with: query) { // High score for exact match from the begining of the title
            score += 200
        } else if title.contains(" \(query)") { // Exact match from the begining of the word within string.
            score += 100
        }

        let domain = bookmark.url.host?.drop(prefix: "www.") ?? ""

        // Tokenized matches
        if queryTokens.count > 1 {
            var matchesAllTokens = true
            for token in queryTokens {
                // Match only from the begining of the word to avoid unintuitive matches.
                if !title.starts(with: token) && !title.contains(" \(token)") && !domain.starts(with: token) {
                    matchesAllTokens = false
                    break
                }
            }

            if matchesAllTokens {
                // Score tokenized matches
                score += 10

                // Boost score if first token matches:
                if let firstToken = queryTokens.first { // domain - high score boost
                    if domain.starts(with: firstToken) {
                        score += 300
                    } else if title.starts(with: firstToken) { // begining of the title - moderate score boost
                        score += 50
                    }
                }
            }
        } else {
            // High score for matching domain in the URL
            if let firstToken = queryTokens.first, domain.starts(with: firstToken) {
                score += 300
            }
        }
        self = score
    }

}
