//
//  Click.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

struct Condition: Codable, Sendable {
    let left: String
    let operation: String
    let right: String
}

struct Choice: Codable, Sendable {
    let condition: Condition
    let expect: String?
    let elements: [PageElement]
}

struct ClickAction: Action {
    let id: String
    let actionType: ActionType
    let elements: [PageElement]
    let dataSource: DataSource?
    let choices: [Choice]?
    let defaultClick: Default?

    enum Default: Codable {
        case null
        case array([PageElement])

        // Custom decoding to handle the different cases
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else {
                let array = try container.decode([PageElement].self)
                self = .array(array)
            }
        }

        // Custom encoding to handle the different cases
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .null:
                try container.encodeNil()
            case .array(let array):
                try container.encode(array)
            }
        }
    }

    // Use CodingKeys so that we can use "default" as the JSON key name, which is invalid in Swift
    private enum CodingKeys: String, CodingKey {
        case id
        case actionType
        case elements
        case dataSource
        case choices
        case defaultClick = "default"
    }
}
