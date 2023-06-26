//
//  CSSRequestParameters.swift
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

public struct InitParams: Encodable {
    let profileData: ProfileQuery
    let dataBrokerData: DataBroker
}

public struct State: Encodable {
    let action: Action
    let profileData: ProfileQuery?

    enum CodingKeys: String, CodingKey {
        case action
        case profileData
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profileData, forKey: .profileData)

        switch action {
        case let navigateAction as NavigateAction:
            try container.encode(navigateAction, forKey: .action)
        case let extractAction as ExtractAction:
            try container.encode(extractAction, forKey: .action)
        case let fillFormAction as FillFormAction:
            try container.encode(fillFormAction, forKey: .action)
        case let clickAction as ClickAction:
            try container.encode(clickAction, forKey: .action)
        case let expectationAction as ExpectationAction:
            try container.encode(expectationAction, forKey: .action)
        default:
            assertionFailure("Action not found. Please add the missing action to the encoding list.")
        }
    }
}

public struct Params: Encodable {
    let state: State
}
