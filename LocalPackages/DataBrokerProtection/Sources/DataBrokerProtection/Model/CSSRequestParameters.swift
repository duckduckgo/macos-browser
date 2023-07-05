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

public enum CCFRequestData: Encodable {
    case profile(ProfileQuery)
    case solveCaptcha(CaptchaToken)
}

public struct CaptchaToken: Encodable, Sendable {
    let token: String
}

public struct InitParams: Encodable {
    let profileData: ProfileQuery
    let dataBrokerData: DataBroker
}

public struct State: Encodable {
    let action: Action
    let profileData: CCFRequestData?

    enum CodingKeys: String, CodingKey {
        case action
        case profileData
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch profileData {
        case .profile(let profileQuery):
            try container.encode(profileQuery, forKey: .profileData)
        case .solveCaptcha(let captchaToken):
            try container.encode(captchaToken, forKey: .profileData)
        default:
            try container.encodeNil(forKey: .profileData)
        }

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
        case let getCaptchaInfo as GetCaptchaInfoAction:
            try container.encode(getCaptchaInfo, forKey: .action)
        case let solveCaptcha as SolveCaptchaAction:
            try container.encode(solveCaptcha, forKey: .action)
        default:
            assertionFailure("Action not found. Please add the missing action to the encoding list.")
        }
    }
}

public struct Params: Encodable {
    let state: State
}
