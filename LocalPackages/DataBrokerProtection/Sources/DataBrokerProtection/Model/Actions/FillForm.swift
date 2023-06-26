//
//  FillForm.swift
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

public struct PageElement: Codable, Sendable {
    let type: String
    let selector: String

    public init(type: String, selector: String) {
        self.type = type
        self.selector = selector
    }
}

public struct FillFormAction: Action {
    public let id: String = "fillForm"
    public let actionType: ActionType = .fillForm

    let selector: String
    let elements: [PageElement]

    public init(selector: String, elements: [PageElement]) {
        self.selector = selector
        self.elements = elements
    }
}
