//
//  SuggestionsAPIResult.swift
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
import os.log

struct SuggestionsAPIResult: Decodable {

    var suggestions: [Suggestion]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        self.suggestions = [Suggestion]()
        while !container.isAtEnd {
            let items = try container.decode([String: String].self)
            for item in items {
                let type = Suggestion.SuggestionType(rawValue: item.key) ?? Suggestion.SuggestionType.unknown
                if type == .unknown {
                    os_log("SuggestionsAPIResult: Unknown suggestion type", log: OSLog.Category.general, type: .debug)
                }
                let suggestion = Suggestion(type: type, value: item.value)
                self.suggestions.append(suggestion)
            }
        }
    }
    
}
