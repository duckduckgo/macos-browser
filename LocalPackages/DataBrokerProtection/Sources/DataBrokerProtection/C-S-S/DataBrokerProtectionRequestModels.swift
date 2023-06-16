//
//  DataBrokerProtectionRequestModels.swift
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

public struct DataBrokerData: Encodable, Sendable {
    let name: String
    let steps: [Step]

    public init(name: String, steps: [Step]) {
        self.name = name
        self.steps = steps
    }

    func scanStep() throws -> Step {
        guard let scanStep = steps.first(where: { $0.type == .scan }) else {
            assertionFailure("Broker is missing the scan step.")
            throw DataBrokerProtectionError.unrecoverableError
        }

        return scanStep
    }
}

public struct ProfileData: Encodable, Sendable {
    let firstName: String
    let lastName: String
    let city: String
    let state: String
    let age: Int

    public init(firstName: String, lastName: String, city: String, state: String, age: Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.city = city
        self.state = state
        self.age = age
    }
}

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

public enum ActionType: String, Codable, Sendable {
    case extract
    case navigate
}

public protocol Action: Encodable, Sendable {
    var id: String { get }
    var actionType: ActionType { get }
}

public struct NavigateAction: Action {
    public var id: String = "navigate"
    public var actionType: ActionType = .navigate
    let url: String
    let ageRange: [String]

    public init(id: String, actionType: ActionType, url: String, ageRange: [String]) {
        self.id = id
        self.actionType = actionType
        self.url = url
        self.ageRange = ageRange
    }
}

public struct ExtractAction: Action {
    public var id: String = "extract"
    public var actionType: ActionType = .extract
    let selector: String
    let profile: ExtractedProfile

    public init(id: String, actionType: ActionType, selector: String, profile: ExtractedProfile) {
        self.id = id
        self.actionType = actionType
        self.selector = selector
        self.profile = profile
    }
}

public struct ExtractedProfile: Codable, Sendable {
    let name: String?
    let alternativeNamesList: String?
    let addressFull: String?
    let addressCityState: String?
    let addressCityStateList: String?
    let phone: String?
    let phoneList: String?
    let relativesList: String?
    let profileUrl: String?
    let reportId: String?
    let age: String?

    public init(name: String? = nil,
                alternativeNamesList: String? = nil,
                addressFull: String? = nil,
                addressCityState: String? = nil,
                addressCityStateList: String? = nil,
                phone: String? = nil,
                phoneList: String? = nil,
                relativesList: String? = nil,
                profileUrl: String? = nil,
                reportId: String? = nil,
                age: String? = nil) {
        self.name = name
        self.alternativeNamesList = alternativeNamesList
        self.addressFull = addressFull
        self.addressCityState = addressCityState
        self.addressCityStateList = addressCityStateList
        self.phone = phone
        self.phoneList = phoneList
        self.relativesList = relativesList
        self.profileUrl = profileUrl
        self.reportId = reportId
        self.age = age
    }
}

public struct InitParams: Encodable {
    let profileData: ProfileData
    let dataBrokerData: DataBrokerData
}

public struct State: Encodable {
    let action: Action
    let profileData: ProfileData?

    enum CodingKeys: String, CodingKey {
        case action
        case profileData
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profileData, forKey: .profileData)
        if let navigateAction = action as? NavigateAction {
            try container.encode(navigateAction, forKey: .action)
        } else if let extractAction = action as? ExtractAction {
            try container.encode(extractAction, forKey: .action)
        }
    }
}

public struct Params: Encodable {
    let state: State
}
