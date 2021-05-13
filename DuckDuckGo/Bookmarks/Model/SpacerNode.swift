//
//  SpacerNode.swift
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

final class SpacerNode: Equatable {

    static let blank = SpacerNode(name: "Blank")
    static let divider = SpacerNode(name: "Divider")

    private let name: String

    // SpacerNode instances don't need to be created directly, they are provided via the static values above.
    private init(name: String) {
        self.name = name
    }

    static func == (lhs: SpacerNode, rhs: SpacerNode) -> Bool {
        return lhs.name == rhs.name
    }

}
