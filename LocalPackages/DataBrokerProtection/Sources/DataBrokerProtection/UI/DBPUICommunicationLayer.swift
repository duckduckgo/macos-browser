//
//  DBPUICommunicationLayer.swift
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
import WebKit
import BrowserServicesKit
import UserScript
import Common

enum DBPUIReceivedMethodName: String {
    case setState
    case getCurrentUserProfile
    case addNameToCurrentUserProfile
    case removeNameFromCurrentUserProfile
    case removeNameAtIndexFromCurrentUserProfile
    case setBirthYearForCurrentUserProfile
    case addAddressToCurrentUserProfile
    case removeAddressFromCurrentUserProfile
    case removeAddressAtIndexFromCurrentUserProfile
    case startScanAndOptOut
}

struct DBPUICommunicationLayer: Subfeature {
    var messageOriginPolicy: MessageOriginPolicy = .all
    var featureName: String = "dbpuiCommunication"
    var broker: UserScriptMessageBroker?

    // swiftlint:disable:next cyclomatic_complexity
    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let actionResult = DBPUIReceivedMethodName(rawValue: methodName) else {
            os_log("Cant parse method: %{public}@", log: .dataBrokerProtection, methodName)
            return nil
        }

        switch actionResult {
        case .setState: return setState
        case .getCurrentUserProfile: return getCurrentUserProfile
        case .addNameToCurrentUserProfile: return addNameToCurrentUserProfile
        case .removeNameFromCurrentUserProfile: return removeNameFromCurrentUserProfile
        case .removeNameAtIndexFromCurrentUserProfile: return removeNameAtIndexFromCurrentUserProfile
        case .setBirthYearForCurrentUserProfile: return setBirthYearForCurrentUserProfile
        case .addAddressToCurrentUserProfile: return addAddressToCurrentUserProfile
        case .removeAddressFromCurrentUserProfile: return removeAddressFromCurrentUserProfile
        case .removeAddressAtIndexFromCurrentUserProfile: return removeAddressAtIndexFromCurrentUserProfile
        case .startScanAndOptOut: return startScanAndOptOut
        }

    }

    func setState(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUISetState.self, from: data) else {
            os_log("Failed to parse setState message", log: .dataBrokerProtection)
            return nil
        }

        print(result.state)

        return nil
    }

    func getCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        // TODO: get user profile
        return nil
    }

    func addNameToCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileName.self, from: data) else {
            os_log("Failed to parse addNameToCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        // TODO: add result to user profile
        return nil
    }

    func removeNameFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileName.self, from: data) else {
            os_log("Failed to parse removeNameFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        // TODO: remove result from user profile
        return nil
    }

    func removeNameAtIndexFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIIndex.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        // TODO: remove result from user profile
        return nil
    }
    
    func setBirthYearForCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIBirthYear.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        // TODO: set result on user profile
        return nil
    }
    
    func addAddressToCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileAddress.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        // TODO: add result to user profile
        return nil
    }

    func removeAddressFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileAddress.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        // TODO: remove result from user profile
        return nil
    }

    func removeAddressAtIndexFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIIndex.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        // TODO: remove address at result from user profile
        return nil
    }

    func startScanAndOptOut(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        // TODO: Return opt out state
        return nil
    }
}
