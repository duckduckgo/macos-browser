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

enum StepType: String, Codable, Sendable {
    case scan
    case optOut
}

struct Step: Codable, Sendable {
    let type: StepType
    let actions: [Action]

    enum CodingKeys: String, CodingKey {
        case actions, stepType
    }

    init(type: StepType, actions: [Action]) {
        self.type = type
        self.actions = actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(StepType.self, forKey: .stepType)

        let actionsList = try container.decode([[String: Any]].self, forKey: .actions)
        actions = try Step.parse(actionsList)
    }

    func encode(to encoder: Encoder) throws {
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

    static func parse(_ actions: [[String: Any]]) throws -> [Action] {
        var actionList = [Action]()

        for list in actions {
            guard let typeValue = list["actionType"] as? String,
                  let actionType = ActionType(rawValue: typeValue) else {
                continue
            }
             let jsonData = try JSONSerialization.data(withJSONObject: list, options: .prettyPrinted)

            switch actionType {
            case .click:
                let action = try JSONDecoder().decode(ClickAction.self, from: jsonData)
                actionList.append(action)
            case .extract:
                let action = try JSONDecoder().decode(ExtractAction.self, from: jsonData)
                actionList.append(action)
            case .fillForm:
                let action = try JSONDecoder().decode(FillFormAction.self, from: jsonData)
                actionList.append(action)
            case .navigate:
                let action = try JSONDecoder().decode(NavigateAction.self, from: jsonData)
                actionList.append(action)
            case .expectation:
                let action = try JSONDecoder().decode(ExpectationAction.self, from: jsonData)
                actionList.append(action)
            case .getCaptchaInfo:
                let action = try JSONDecoder().decode(GetCaptchaInfoAction.self, from: jsonData)
                actionList.append(action)
            case .solveCaptcha:
                let action = try JSONDecoder().decode(SolveCaptchaAction.self, from: jsonData)
                actionList.append(action)
            case .emailConfirmation:
                let action = try JSONDecoder().decode(EmailConfirmationAction.self, from: jsonData)
                actionList.append(action)
            }
        }

        return actionList
    }
}
