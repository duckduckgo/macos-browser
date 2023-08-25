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
    func getUserProfile() -> UserProfile
    func addNameToCurrentUserProfile(_ name: UserProfileName) -> Bool
    func removeNameFromUserProfile(_ name: UserProfileName) -> Bool
    func removeNameAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool
    func setBirthYearForCurrentUserProfile(_ year: DBPUIBirthYear)
    func addAddressToCurrentUserProfile(_ address: UserProfileAddress) -> Bool
    func removeAddressFromCurrentUserProfile(_ address: UserProfileAddress) -> Bool
    func removeAddressAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool
    func startScanAndOptOut() -> Bool
}

enum DBPUIReceivedMethodName: String {
    case handshake
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
        case .removeNameFromCurrentUserProfile: return removeNameFromCurrentUserProfile
        case .removeNameAtIndexFromCurrentUserProfile: return removeNameAtIndexFromCurrentUserProfile
        case .setBirthYearForCurrentUserProfile: return setBirthYearForCurrentUserProfile
        case .addAddressToCurrentUserProfile: return addAddressToCurrentUserProfile
        case .removeAddressFromCurrentUserProfile: return removeAddressFromCurrentUserProfile
        case .removeAddressAtIndexFromCurrentUserProfile: return removeAddressAtIndexFromCurrentUserProfile
        case .startScanAndOptOut: return startScanAndOptOut
        }

    }

    func handshake(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIHandshake.self, from: data) else {
            os_log("Failed to parse setState message", log: .dataBrokerProtection)
            return DBPUIHandshakeResponse(version: Constants.version, success: false)
        }

        if result.version != Constants.version {
            return DBPUIHandshakeResponse(version: Constants.version, success: false)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: true)
    }

    func setState(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUISetState.self, from: data) else {
            os_log("Failed to parse setState message", log: .dataBrokerProtection)
            return nil
        }

        os_log("Web UI requested new state: \(result.state.rawValue)", log: .dataBrokerProtection)

        delegate?.setState()

        return nil
    }

    func getCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        return delegate?.getUserProfile()
    }

    func addNameToCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileName.self, from: data) else {
            os_log("Failed to parse addNameToCurrentUserProfile message", log: .dataBrokerProtection)
            return DBPUIHandshakeResponse(version: Constants.version, success: false)
        }

        if delegate?.addNameToCurrentUserProfile(result) == true {
            return DBPUIHandshakeResponse(version: Constants.version, success: true)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: false)
    }

    func removeNameFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileName.self, from: data) else {
            os_log("Failed to parse removeNameFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        if delegate?.removeNameFromUserProfile(result) == true {
            return DBPUIHandshakeResponse(version: Constants.version, success: true)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: false)
    }

    func removeNameAtIndexFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIIndex.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        if delegate?.removeNameAtIndexFromUserProfile(result) == true {
            return DBPUIHandshakeResponse(version: Constants.version, success: true)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: false)
    }

    func setBirthYearForCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIBirthYear.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        delegate?.setBirthYearForCurrentUserProfile(result)

        return nil
    }

    func addAddressToCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileAddress.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        if delegate?.addAddressToCurrentUserProfile(result) == true {
            return DBPUIHandshakeResponse(version: Constants.version, success: true)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: false)
    }

    func removeAddressFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(UserProfileAddress.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        if delegate?.removeAddressFromCurrentUserProfile(result) == true {
            return DBPUIHandshakeResponse(version: Constants.version, success: true)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: false)
    }

    func removeAddressAtIndexFromCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIIndex.self, from: data) else {
            os_log("Failed to parse removeNameAtIndexFromCurrentUserProfile message", log: .dataBrokerProtection)
            return nil
        }

        if delegate?.removeAddressAtIndexFromUserProfile(result) == true {
            return DBPUIHandshakeResponse(version: Constants.version, success: true)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: false)
    }

    func startScanAndOptOut(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        if delegate?.startScanAndOptOut() == true {
            return DBPUIHandshakeResponse(version: Constants.version, success: true)
        }

        return DBPUIHandshakeResponse(version: Constants.version, success: false)
    }

    func sendMessageToUI(method: DBPUISendableMethodName, params: DBPUISendableMessage, into webView: WKWebView) {
        broker?.push(method: method.rawValue, params: params, for: self, into: webView)
    }
}
