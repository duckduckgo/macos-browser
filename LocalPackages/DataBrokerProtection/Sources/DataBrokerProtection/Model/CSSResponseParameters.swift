//
//  CSSResponseParameters.swift
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

enum CSSSuccessData {
    case navigate(NavigateResponse)
    case extract([ExtractedProfile])
    case fillForm
    case click
    case expectation
}

struct CSSSuccessResponse: Decodable {
    let actionID: String
    let actionType: ActionType
    let response: CSSSuccessData?

    enum CodingKeys: CodingKey {
        case actionID
        case actionType
        case response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.actionID = try container.decode(String.self, forKey: .actionID)
        self.actionType = try container.decode(ActionType.self, forKey: .actionType)

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
        }
    }
}

struct CSSErrorResponse: Decodable {
    let actionID: String
    let message: String
}

struct CSSSuccess: Decodable {
    let success: CSSSuccessResponse
}

struct CSSErrorWrapper: Decodable {
    let error: CSSErrorResponse
}

enum CSSResultResponse {
    case success(CSSSuccessResponse)
    case error(CSSErrorResponse)
}

struct CSSResult: Decodable {
    let result: CSSResultResponse

    enum CodingKeys: CodingKey {
        case result
        case success
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let success = try? container.decode(CSSSuccess.self, forKey: .result) {
            result = .success(success.success)
        } else if let error = try? container.decode(CSSErrorWrapper.self, forKey: .result) {
            result = .error(error.error)
        } else {
            throw DataBrokerProtectionError.parsingErrorObjectFailed
        }
    }
}
