//
//  CCFRequestParameters.swift
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

enum CCFRequestData: Encodable {
    case solveCaptcha(CaptchaToken)
    case userData(ProfileQuery, ExtractedProfile?)
}

struct CaptchaToken: Encodable, Sendable {
    let token: String
}

struct InitParams: Encodable {
    let profileData: ProfileQuery
    let dataBrokerData: DataBroker
}

private enum UserDataCodingKeys: String, CodingKey {
    case userProfile
    case extractedProfile
}

struct ActionRequest: Encodable {
    let action: Action
    let data: CCFRequestData?

    enum CodingKeys: String, CodingKey {
        case action
        case data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch data {
        case .solveCaptcha(let captchaToken):
            try container.encode(captchaToken, forKey: .data)
        case .userData(let profileQuery, let extractedProfile):
            var userDataContainer = container.nestedContainer(keyedBy: UserDataCodingKeys.self, forKey: .data)
            try userDataContainer.encode(profileQuery, forKey: .userProfile)
            if let extractedProfile = extractedProfile {
                try userDataContainer.encode(extractedProfile, forKey: .extractedProfile)
            }
        default:
            assertionFailure("Data not found. Please add the mission data to the encoding list.")
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

struct Params: Encodable {
    let state: ActionRequest
}
