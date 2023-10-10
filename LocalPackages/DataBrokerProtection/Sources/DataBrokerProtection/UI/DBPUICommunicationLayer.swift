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

protocol DBPUICommunicationDelegate: AnyObject {
    func setState()
    func getUserProfile() -> DBPUIUserProfile?
    func addNameToCurrentUserProfile(_ name: DBPUIUserProfileName) -> Bool
    func setNameAtIndexInCurrentUserProfile(_ payload: DBPUINameAtIndex) -> Bool
    func removeNameAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool
    func setBirthYearForCurrentUserProfile(_ year: DBPUIBirthYear) -> Bool
    func addAddressToCurrentUserProfile(_ address: DBPUIUserProfileAddress) -> Bool
    func setAddressAtIndexInCurrentUserProfile(_ payload: DBPUIAddressAtIndex) -> Bool
    func removeAddressAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool
    func startScanAndOptOut() -> Bool
}

enum DBPUIReceivedMethodName: String {
    case handshake
    case setState
    case getCurrentUserProfile
    case addNameToCurrentUserProfile
    case setNameAtIndexInCurrentUserProfile
    case removeNameAtIndexFromCurrentUserProfile
    case setBirthYearForCurrentUserProfile
    case addAddressToCurrentUserProfile
    case setAddressAtIndexInCurrentUserProfile
    case removeAddressAtIndexFromCurrentUserProfile
    case startScanAndOptOut
}

enum DBPUISendableMethodName: String {
    case setState
    case scanAndOptOutStatusChanged
}

struct DBPUICommunicationLayer: Subfeature {
    var messageOriginPolicy: MessageOriginPolicy = .all
    var featureName: String = "dbpuiCommunication"
    var broker: UserScriptMessageBroker?

    weak var delegate: DBPUICommunicationDelegate?

    private enum Constants {
        static let version = 1
    }

    // swiftlint:disable:next cyclomatic_complexity
    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let actionResult = DBPUIReceivedMethodName(rawValue: methodName) else {
            os_log("Cant parse method: %{public}@", log: .dataBrokerProtection, methodName)
            return nil
        }

        switch actionResult {
        case .handshake: return handshake
        case .setState: return setState
        case .getCurrentUserProfile: return getCurrentUserProfile
        case .addNameToCurrentUserProfile: return addNameToCurrentUserProfile
        case .setNameAtIndexInCurrentUserProfile: return setNameAtIndexInCurrentUserProfile
        case .removeNameAtIndexFromCurrentUserProfile: return removeNameAtIndexFromCurrentUserProfile
        case .setBirthYearForCurrentUserProfile: return setBirthYearForCurrentUserProfile
        case .addAddressToCurrentUserProfile: return addAddressToCurrentUserProfile
        case .setAddressAtIndexInCurrentUserProfile: return setAddressAtIndexInCurrentUserProfile
        case .removeAddressAtIndexFromCurrentUserProfile: return removeAddressAtIndexFromCurrentUserProfile
        case .startScanAndOptOut: return startScanAndOptOut
        }

    }

    func handshake(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIHandshake.self, from: data) else {
            os_log("Failed to parse handshake message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if result.version != Constants.version {
            os_log("Incorrect protocol version presented by UI", log: .dataBrokerProtection)
            return DBPUIStandardResponse(version: Constants.version, success: false)
        }

        os_log("Successful handshake made by UI", log: .dataBrokerProtection)
        return DBPUIStandardResponse(version: Constants.version, success: true)
    }

    func setState(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUISetState.self, from: data) else {
            os_log("Failed to parse setState message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        os_log("Web UI requested new state: \(result.state.rawValue)", log: .dataBrokerProtection)

        delegate?.setState()

        return nil
    }

    func getCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let profile = delegate?.getUserProfile() else {
            return DBPUIStandardResponse(version: Constants.version, success: false, id: "NOT_FOUND", message: "No user profile found")
        }

        return profile
    }

    func addNameToCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIUserProfileName.self, from: data) else {
            os_log("Failed to parse addNameToCurrentUserProfile message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if delegate?.addNameToCurrentUserProfile(result) == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func setNameAtIndexInCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUINameAtIndex.self, from: data) else {
            os_log("Failed to parse removeNameFromCurrentUserProfile message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if delegate?.setNameAtIndexInCurrentUserProfile(result) == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func removeNameAtIndexFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIIndex.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if delegate?.removeNameAtIndexFromUserProfile(result) == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func setBirthYearForCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIBirthYear.self, from: data) else {
            os_log("Failed to parse setBirthYearForCurrentUserProfile message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if delegate?.setBirthYearForCurrentUserProfile(result) == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func addAddressToCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIUserProfileAddress.self, from: data) else {
            os_log("Failed to parse addAddressToCurrentUserProfile message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if delegate?.addAddressToCurrentUserProfile(result) == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func setAddressAtIndexInCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIAddressAtIndex.self, from: data) else {
            os_log("Failed to parse removeAddressFromCurrentUserProfile message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if delegate?.setAddressAtIndexInCurrentUserProfile(result) == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func removeAddressAtIndexFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIIndex.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            throw DBPUIError.malformedRequest
        }

        if delegate?.removeAddressAtIndexFromUserProfile(result) == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func startScanAndOptOut(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if delegate?.startScanAndOptOut() == true {
            return DBPUIStandardResponse(version: Constants.version, success: true)
        }

        return DBPUIStandardResponse(version: Constants.version, success: false)
    }

    func sendMessageToUI(method: DBPUISendableMethodName, params: DBPUISendableMessage, into webView: WKWebView) {
        broker?.push(method: method.rawValue, params: params, for: self, into: webView)
    }
}
