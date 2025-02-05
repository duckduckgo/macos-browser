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
import os.log

protocol DBPUICommunicationDelegate: AnyObject {
    func getHandshakeUserData() -> DBPUIHandshakeUserData?
    func saveProfile() async throws
    func getUserProfile() -> DBPUIUserProfile?
    func deleteProfileData() throws
    func addNameToCurrentUserProfile(_ name: DBPUIUserProfileName) -> Bool
    func setNameAtIndexInCurrentUserProfile(_ payload: DBPUINameAtIndex) -> Bool
    func removeNameAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool
    func setBirthYearForCurrentUserProfile(_ year: DBPUIBirthYear) -> Bool
    func addAddressToCurrentUserProfile(_ address: DBPUIUserProfileAddress) -> Bool
    func setAddressAtIndexInCurrentUserProfile(_ payload: DBPUIAddressAtIndex) -> Bool
    func removeAddressAtIndexFromUserProfile(_ index: DBPUIIndex) -> Bool
    func startScanAndOptOut() -> Bool
    func getInitialScanState() async -> DBPUIInitialScanState
    func getMaintananceScanState() async -> DBPUIScanAndOptOutMaintenanceState
    func getDataBrokers() async -> [DBPUIDataBroker]
    func getBackgroundAgentMetadata() async -> DBPUIDebugMetadata
    func openSendFeedbackModal() async
}

enum DBPUIReceivedMethodName: String {
    case handshake
    case saveProfile
    case getCurrentUserProfile
    case deleteUserProfileData
    case addNameToCurrentUserProfile
    case setNameAtIndexInCurrentUserProfile
    case removeNameAtIndexFromCurrentUserProfile
    case setBirthYearForCurrentUserProfile
    case addAddressToCurrentUserProfile
    case setAddressAtIndexInCurrentUserProfile
    case removeAddressAtIndexFromCurrentUserProfile
    case startScanAndOptOut
    case initialScanStatus
    case maintenanceScanStatus
    case getDataBrokers
    case getBackgroundAgentMetadata
    case getFeatureConfig
    case openSendFeedbackModal
}

enum DBPUISendableMethodName: String {
    case setState
}

struct DBPUICommunicationLayer: Subfeature {
    private let webURLSettings: DataBrokerProtectionWebUIURLSettingsRepresentable
    private let privacyConfig: PrivacyConfigurationManaging

    var messageOriginPolicy: MessageOriginPolicy
    var featureName: String = "dbpuiCommunication"
    weak var broker: UserScriptMessageBroker?

    weak var delegate: DBPUICommunicationDelegate?

    private enum Constants {
        static let version = 8
    }

    internal init(webURLSettings: DataBrokerProtectionWebUIURLSettingsRepresentable,
                  privacyConfig: PrivacyConfigurationManaging) {
        self.webURLSettings = webURLSettings
        self.privacyConfig = privacyConfig
        self.messageOriginPolicy = .only(rules: [
            .exact(hostname: webURLSettings.selectedURLHostname)
        ])
    }

    func handler(forMethodNamed methodName: String) -> Handler? {
        guard let actionResult = DBPUIReceivedMethodName(rawValue: methodName) else {
            Logger.dataBrokerProtection.log("Cant parse method: \(methodName, privacy: .public)")
            return nil
        }

        switch actionResult {
        case .handshake: return handshake
        case .saveProfile: return saveProfile
        case .getCurrentUserProfile: return getCurrentUserProfile
        case .deleteUserProfileData: return deleteUserProfileData
        case .addNameToCurrentUserProfile: return addNameToCurrentUserProfile
        case .setNameAtIndexInCurrentUserProfile: return setNameAtIndexInCurrentUserProfile
        case .removeNameAtIndexFromCurrentUserProfile: return removeNameAtIndexFromCurrentUserProfile
        case .setBirthYearForCurrentUserProfile: return setBirthYearForCurrentUserProfile
        case .addAddressToCurrentUserProfile: return addAddressToCurrentUserProfile
        case .setAddressAtIndexInCurrentUserProfile: return setAddressAtIndexInCurrentUserProfile
        case .removeAddressAtIndexFromCurrentUserProfile: return removeAddressAtIndexFromCurrentUserProfile
        case .startScanAndOptOut: return startScanAndOptOut
        case .initialScanStatus: return initialScanStatus
        case .maintenanceScanStatus: return maintenanceScanStatus
        case .getDataBrokers: return getDataBrokers
        case .getBackgroundAgentMetadata: return getBackgroundAgentMetadata
        case .getFeatureConfig: return getFeatureConfig
        case .openSendFeedbackModal: return openSendFeedbackModal
        }

    }

    func handshake(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIHandshake.self, from: data) else {
            Logger.dataBrokerProtection.log("Failed to parse handshake message")
            throw DBPUIError.malformedRequest
        }

        // Attempt to get handshake user data, but fallback to a default
        let userData = delegate?.getHandshakeUserData() ?? DBPUIHandshakeUserData(isAuthenticatedUser: true)

        if result.version != Constants.version {
            Logger.dataBrokerProtection.log("Incorrect protocol version presented by UI")
            return DBPUIHandshakeResponse(version: Constants.version, success: false, userdata: userData)
        }

        Logger.dataBrokerProtection.log("Successful handshake made by UI")
        return DBPUIHandshakeResponse(version: Constants.version, success: true, userdata: userData)
    }

    func saveProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        Logger.dataBrokerProtection.log("Web UI requested to save the profile")

        do {
            try await delegate?.saveProfile()
            return DBPUIStandardResponse(version: Constants.version, success: true)
        } catch {
            Logger.dataBrokerProtection.error("DBPUICommunicationLayer saveProfile, error: \(error.localizedDescription, privacy: .public)")
            return DBPUIStandardResponse(version: Constants.version, success: false)
        }
    }

    func getCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let profile = delegate?.getUserProfile() else {
            return DBPUIStandardResponse(version: Constants.version, success: false, id: "NOT_FOUND", message: "No user profile found")
        }

        return profile
    }

    func deleteUserProfileData(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        do {
            try delegate?.deleteProfileData()
            return DBPUIStandardResponse(version: Constants.version, success: true)
        } catch {
            Logger.dataBrokerProtection.error("DBPUICommunicationLayer deleteUserProfileData, error: \(error.localizedDescription, privacy: .public)")
            return DBPUIStandardResponse(version: Constants.version, success: false)
        }
    }

    func addNameToCurrentUserProfile(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        guard let data = try? JSONSerialization.data(withJSONObject: params),
                let result = try? JSONDecoder().decode(DBPUIUserProfileName.self, from: data) else {
            Logger.dataBrokerProtection.log("Failed to parse addNameToCurrentUserProfile message")
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
            Logger.dataBrokerProtection.log("Failed to parse removeNameFromCurrentUserProfile message")
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
            Logger.dataBrokerProtection.log("Failed to parse removeNameAtIndexFromCurrentUserProfile message")
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
            Logger.dataBrokerProtection.log("Failed to parse setBirthYearForCurrentUserProfile message")
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
            Logger.dataBrokerProtection.log("Failed to parse addAddressToCurrentUserProfile message")
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
            Logger.dataBrokerProtection.log("Failed to parse removeAddressFromCurrentUserProfile message")
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
            Logger.dataBrokerProtection.log("Failed to parse removeNameAtIndexFromCurrentUserProfile message")
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

    func initialScanStatus(params: Any, origin: WKScriptMessage) async throws -> Encodable? {
        guard let initialScanState = await delegate?.getInitialScanState() else {
            return DBPUIStandardResponse(version: Constants.version, success: false, id: "NOT_FOUND", message: "No initial scan data found")
        }

        return initialScanState
    }

    func maintenanceScanStatus(params: Any, origin: WKScriptMessage) async throws -> Encodable? {
        guard let maintenanceScanStatus = await delegate?.getMaintananceScanState() else {
            return DBPUIStandardResponse(version: Constants.version, success: false, id: "NOT_FOUND", message: "No maintenance data found")
        }

        return maintenanceScanStatus
    }

    func getDataBrokers(params: Any, origin: WKScriptMessage) async throws -> Encodable? {
        let dataBrokers = await delegate?.getDataBrokers() ?? [DBPUIDataBroker]()
        return DBPUIDataBrokerList(dataBrokers: dataBrokers)
    }

    func getBackgroundAgentMetadata(params: Any, origin: WKScriptMessage) async throws -> Encodable? {
        return await delegate?.getBackgroundAgentMetadata()
    }

    func sendMessageToUI(method: DBPUISendableMethodName, params: DBPUISendableMessage, into webView: WKWebView) {
        broker?.push(method: method.rawValue, params: params, for: self, into: webView)
    }

    func getFeatureConfig(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        [PrivacyProSubfeature.useUnifiedFeedback.rawValue: privacyConfig.privacyConfig.isSubfeatureEnabled(PrivacyProSubfeature.useUnifiedFeedback)]
    }

    func openSendFeedbackModal(params: Any, original: WKScriptMessage) async throws -> Encodable? {
        await delegate?.openSendFeedbackModal()
        return nil
    }
}
