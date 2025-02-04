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

enum OptOutType: String, Codable, Sendable {
    case formOptOut
    case parentSiteOptOut
}

struct Step: Codable, Sendable {
    let type: StepType
    let optOutType: OptOutType?
    let actions: [Action]

    enum CodingKeys: String, CodingKey {
        case actions, stepType, optOutType
    }

    init(type: StepType, actions: [Action], optOutType: OptOutType? = nil) {
        self.type = type
        self.actions = actions
        self.optOutType = optOutType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(StepType.self, forKey: .stepType)
        optOutType = try? container.decode(OptOutType.self, forKey: .optOutType)

        let actionsList = try container.decode([[String: Any]].self, forKey: .actions)
        actions = try Step.parse(actionsList)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .stepType)
        try container.encode(optOutType, forKey: .optOutType)

        var actionsContainer = container.nestedUnkeyedContainer(forKey: .actions)
        try actions.encode(to: &actionsContainer)
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

extension Array where Element == Action {
    func encode(to container: inout any UnkeyedEncodingContainer) throws {
        for action in self {
            if let navigateAction = action as? NavigateAction {
                try container.encode(navigateAction)
            } else if let extractAction = action as? ExtractAction {
                try container.encode(extractAction)
            } else if let fillFormAction = action as? FillFormAction {
                try container.encode(fillFormAction)
            } else if let getCaptchaInfoAction = action as? GetCaptchaInfoAction {
                try container.encode(getCaptchaInfoAction)
            } else if let solveCaptchaInfoAction = action as? SolveCaptchaAction {
                try container.encode(solveCaptchaInfoAction)
            } else if let emailConfirmationAction = action as? EmailConfirmationAction {
                try container.encode(emailConfirmationAction)
            } else if let clickAction = action as? ClickAction {
                try container.encode(clickAction)
            } else if let expectactionAction = action as? ExpectationAction {
                try container.encode(expectactionAction)
            }
        }
    }
}
