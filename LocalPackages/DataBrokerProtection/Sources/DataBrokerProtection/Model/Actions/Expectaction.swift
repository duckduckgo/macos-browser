//
//  Expectaction.swift
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

enum ItemType: String, Codable, Sendable {
    case text
    case url
    case element
}

struct Item: Codable, Sendable {
    let type: ItemType
    let expect: String?
    let selector: String?
    let parent: String?
    let failSilently: Bool?
}

internal final class ExpectationAction: Action {
    let id: String
    let actionType: ActionType
    let expectations: [Item]
    let dataSource: DataSource?
    let actions: [Action]?

    enum CodingKeys: String, CodingKey {
        case id, actionType, expectations, dataSource, actions
    }

    init(id: String, actionType: ActionType, expectations: [Item], dataSource: DataSource?, actions: [Action]?) {
        self.id = id
        self.actionType = actionType
        self.expectations = expectations
        self.dataSource = dataSource
        self.actions = actions
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.actionType = try container.decode(ActionType.self, forKey: .actionType)
        self.expectations = try container.decode([Item].self, forKey: .expectations)
        self.dataSource = try container.decodeIfPresent(DataSource.self, forKey: .dataSource)
        let actionsList = try container.decodeIfPresent([[String: Any]].self, forKey: .actions)
        if let actionsList = actionsList {
            self.actions = try Step.parse(actionsList)
        } else {
            self.actions = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(actionType, forKey: .actionType)
        try container.encode(expectations, forKey: .expectations)
        try container.encode(dataSource, forKey: .dataSource)

        var actionsContainer = container.nestedUnkeyedContainer(forKey: .actions)
        try actions?.encode(to: &actionsContainer)
    }
}
