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
    case element = "elementExpectation"
}

struct Item: Codable, Sendable {
    let type: ItemType
    let expect: String?
    let selector: String?
}

internal struct ExpectationAction: Action {
    let id: String
    let actionType: ActionType
    let expectations: [Item]
}
