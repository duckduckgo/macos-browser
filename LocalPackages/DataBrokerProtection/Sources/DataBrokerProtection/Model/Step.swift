//
//  Step.swift
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

public enum StepType: Sendable {
    case scan
    case optOut
}

public struct Step: Encodable, Sendable {
    let type: StepType
    let actions: [Action]

    enum CodingKeys: String, CodingKey {
        case actions
    }

    public init(type: StepType, actions: [Action]) {
        self.type = type
        self.actions = actions
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var actionsContainer = container.nestedUnkeyedContainer(forKey: .actions)
        for action in actions {
            if let navigateAction = action as? NavigateAction {
                try actionsContainer.encode(navigateAction)
            } else if let extractAction = action as? ExtractAction {
                try actionsContainer.encode(extractAction)
            }
        }
    }
}
