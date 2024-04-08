//
//  CCFResponseParameters.swift
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

struct NavigateResponse: Decodable {
    let url: String
}

struct SolveCaptchaCallback: Encodable {
    let callback: String
    let token: String
}

struct GetCaptchaInfoResponse: Decodable {
    let siteKey: String
    let url: String
    let type: String

    enum CodingKeys: CodingKey {
        case siteKey
        case url
        case type
    }

    init(siteKey: String, url: String, type: String) {
        self.siteKey = siteKey
        self.url = url
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.siteKey = try container.decode(String.self, forKey: .siteKey)
        self.url = try container.decode(String.self, forKey: .url)
        self.type = try container.decode(String.self, forKey: .type)
    }
}

struct EvalResponse: Decodable {
    let eval: String
}

struct SolveCaptchaResponse: Decodable {
    let callback: EvalResponse
}

enum CCFSuccessData {
    case navigate(NavigateResponse)
    case extract([ExtractedProfile])
    case fillForm
    case click
    case expectation
    case getCaptchaInfo(GetCaptchaInfoResponse)
    case solveCaptcha(SolveCaptchaResponse)
}

struct CCFSuccessResponse: Decodable {
    let actionID: String
    let actionType: ActionType
    let response: CCFSuccessData?
    let meta: [String: Any]?

    enum CodingKeys: CodingKey {
        case actionID
        case actionType
        case response
        case meta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.actionID = try container.decode(String.self, forKey: .actionID)
        self.actionType = try container.decode(ActionType.self, forKey: .actionType)
        self.meta = try container.decodeIfPresent([String: Any].self, forKey: .meta)

        switch actionType {
        case .navigate:
            self.response = .navigate(try container.decode(NavigateResponse.self, forKey: .response))
        case .extract:
            self.response = .extract(try container.decode([ExtractedProfile].self, forKey: .response))
        case .fillForm:
            self.response = .fillForm
        case .click:
            self.response = .click
        case .expectation:
            self.response = .expectation
        case .emailConfirmation:
            self.response = nil // Email confirmation is done on the native side. We shouldn't have a response here
        case .getCaptchaInfo:
            self.response = .getCaptchaInfo(try container.decode(GetCaptchaInfoResponse.self, forKey: .response))
        case .solveCaptcha:
            self.response = .solveCaptcha(try container.decode(SolveCaptchaResponse.self, forKey: .response))
        }
    }
}

struct CCFErrorResponse: Decodable {
    let actionID: String
    let message: String
}

struct CCFSuccess: Decodable {
    let success: CCFSuccessResponse
}

struct CCFErrorWrapper: Decodable {
    let error: CCFErrorResponse
}

enum CCFResultResponse {
    case success(CCFSuccessResponse)
    case error(CCFErrorResponse)
}

struct CCFResult: Decodable {
    let result: CCFResultResponse

    enum CodingKeys: CodingKey {
        case result
        case success
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let success = try? container.decode(CCFSuccess.self, forKey: .result) {
            result = .success(success.success)
        } else if let error = try? container.decode(CCFErrorWrapper.self, forKey: .result) {
            result = .error(error.error)
        } else {
            throw DataBrokerProtectionError.parsingErrorObjectFailed
        }
    }
}
