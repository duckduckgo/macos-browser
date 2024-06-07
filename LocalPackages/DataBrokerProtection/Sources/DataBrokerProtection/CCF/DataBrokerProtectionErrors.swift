//
//  DataBrokerProtectionErrors.swift
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

struct CCFError: Decodable {
    let error: String
}

public enum DataBrokerProtectionError: Error, Equatable, Codable {
    case malformedURL
    case noActionFound
    case actionFailed(actionID: String, message: String)
    case parsingErrorObjectFailed
    case unknownMethodName
    case userScriptMessageBrokerNotSet
    case unknown(String)
    case unrecoverableError
    case noOptOutStep
    case captchaServiceError(CaptchaServiceError)
    case emailError(EmailError?)
    case cancelled
    case solvingCaptchaWithCallbackError
    case cantCalculatePreferredRunDate
    case httpError(code: Int)
    case dataNotInDatabase

    static func parse(params: Any) -> DataBrokerProtectionError {
        let errorDataResult = try? JSONSerialization.data(withJSONObject: params)

        if let data = errorDataResult {
            if let result = try? JSONDecoder().decode(CCFError.self, from: data) {
                switch result.error {
                case "No action found.": return .noActionFound
                default: return .unknown(result.error)
                }
            }
        }

        return .parsingErrorObjectFailed
    }
}

extension DataBrokerProtectionError {
    var name: String {
        switch self {
        case .malformedURL:
            return "malformedURL"
        case .noActionFound:
            return "noActionFound"
        case .actionFailed:
            return "actionFailed"
        case .parsingErrorObjectFailed:
            return "parsingErrorObjectFailed"
        case .unknownMethodName:
            return "unknownMethodName"
        case .userScriptMessageBrokerNotSet:
            return "userScriptMessageBrokerNotSet"
        case .unknown(let name):
            return name
        case .unrecoverableError:
            return "unrecoverableError"
        case .noOptOutStep:
            return "noOptOutStep"
        case .captchaServiceError:
            return "captchaServiceError"
        case .emailError:
            return "emailError"
        case .cancelled:
            return "Cancelled"
        case .solvingCaptchaWithCallbackError:
            return "Solving captcha with callback failed"
        case .cantCalculatePreferredRunDate:
            return "cantCalculatePreferredRunDate"
        case .httpError:
            return "httpError"
        case .dataNotInDatabase:
            return "dataNotInDatabase"
        }
    }
}
