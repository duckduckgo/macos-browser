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
    let elements: [PageElement]
}

struct ClickAction: Action {
    let id: String
    let actionType: ActionType
    let elements: [PageElement]?
    let dataSource: DataSource?
    let choices: [Choice]?
    let `default`: Default?

    let hasDefault: Bool

    struct Default: Codable {
        let elements: [PageElement]?
    }

    init(id: String, actionType: ActionType, elements: [PageElement]? = nil, dataSource: DataSource? = nil, choices: [Choice]? = nil, `default`: Default? = nil, hasDefault: Bool = false) {
       self.id = id
       self.actionType = actionType
       self.elements = elements
       self.dataSource = dataSource
       self.choices = choices
       self.default = `default`
       self.hasDefault = `default` != nil
   }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.actionType = try container.decode(ActionType.self, forKey: .actionType)
        self.elements = try container.decodeIfPresent([PageElement].self, forKey: .elements)
        self.dataSource = try container.decodeIfPresent(DataSource.self, forKey: .dataSource)
        self.choices = try container.decodeIfPresent([Choice].self, forKey: .choices)
        self.default = try container.decodeIfPresent(Default.self, forKey: .default)
        self.hasDefault = container.contains(.default)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case actionType
        case elements
        case dataSource
        case choices
        case `default`
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.actionType, forKey: .actionType)
        try container.encodeIfPresent(self.elements, forKey: .elements)
        try container.encodeIfPresent(self.dataSource, forKey: .dataSource)
        try container.encodeIfPresent(self.choices, forKey: .choices)

        if self.hasDefault {
            try container.encode(self.default, forKey: .default)
        } else {
            try container.encodeNil(forKey: .default)
        }
    }
}
