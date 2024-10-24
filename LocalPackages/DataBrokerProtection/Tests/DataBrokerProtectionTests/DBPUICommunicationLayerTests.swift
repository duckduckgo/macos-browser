//
//  DBPUICommunicationLayerTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import XCTest
import WebKit
@testable import DataBrokerProtection

final class DBPUICommunicationLayerTests: XCTestCase {

    func testWhenHandshakeCalled_andDelegateAuthenticatedUserTrue_thenHandshakeUserDataTrue() async throws {
        // Given
        let mockDelegate = MockDelegate()
        let handshakeUserData = DBPUIHandshakeUserData(isAuthenticatedUser: true)
        mockDelegate.handshakeUserDataToReturn = handshakeUserData
        var sut = DBPUICommunicationLayer(webURLSettings: MockWebSettings(), privacyConfig: PrivacyConfigurationManagingMock())
        sut.delegate = mockDelegate
        let handshakeParams: [String: Any] = ["version": 4]
        let scriptMessage = await WKScriptMessage()

        // When
        let handler = sut.handler(forMethodNamed: DBPUIReceivedMethodName.handshake.rawValue)
        let result = try await handler?(handshakeParams, scriptMessage)

        // Then
        XCTAssertTrue(mockDelegate.handshakeUserDataCalled)

        guard let resultUserData = result as? DBPUIHandshakeResponse else {
            XCTFail("Expected DBPUIHandshakeResponse to be returned")
            return
        }

        XCTAssertEqual(resultUserData.userdata.isAuthenticatedUser, true)
    }

    func testWhenHandshakeCalled_andDelegateAuthenticatedUserFalse_thenHandshakeUserDataFalse() async throws {
        // Given
        let mockDelegate = MockDelegate()
        let handshakeUserData = DBPUIHandshakeUserData(isAuthenticatedUser: false)
        mockDelegate.handshakeUserDataToReturn = handshakeUserData
        var sut = DBPUICommunicationLayer(webURLSettings: MockWebSettings(), privacyConfig: PrivacyConfigurationManagingMock())
        sut.delegate = mockDelegate
        let handshakeParams: [String: Any] = ["version": 4]
        let scriptMessage = await WKScriptMessage()

        // When
        let handler = sut.handler(forMethodNamed: DBPUIReceivedMethodName.handshake.rawValue)
        let result = try await handler?(handshakeParams, scriptMessage)

        // Then
        XCTAssertTrue(mockDelegate.handshakeUserDataCalled)

        guard let resultUserData = result as? DBPUIHandshakeResponse else {
            XCTFail("Expected DBPUIHandshakeResponse to be returned")
            return
        }

        XCTAssertEqual(resultUserData.userdata.isAuthenticatedUser, false)
    }

    func testWhenHandshakeCalled_andDelegateIsNil_thenHandshakeUserDataIsDefaultTrue() async throws {
        // Given
        let sut = DBPUICommunicationLayer(webURLSettings: MockWebSettings(), privacyConfig: PrivacyConfigurationManagingMock())
        let handshakeParams: [String: Any] = ["version": 4]
        let scriptMessage = await WKScriptMessage()

        // When
        let handler = sut.handler(forMethodNamed: DBPUIReceivedMethodName.handshake.rawValue)
        let result = try await handler?(handshakeParams, scriptMessage)

        // Then
        guard let resultUserData = result as? DBPUIHandshakeResponse else {
            XCTFail("Expected DBPUIHandshakeResponse to be returned")
            return
        }

        XCTAssertEqual(resultUserData.userdata.isAuthenticatedUser, true)
    }
}

// MARK: - Mock Classes

private final class MockDelegate: DBPUICommunicationDelegate {
    var handshakeUserDataCalled = false
    var handshakeUserDataToReturn: DBPUIHandshakeUserData?

    func getHandshakeUserData() -> DBPUIHandshakeUserData? {
        handshakeUserDataCalled = true
        return handshakeUserDataToReturn
    }

    func saveProfile() async throws {}
    func getUserProfile() -> DBPUIUserProfile? { nil }
    func deleteProfileData() throws {}
    func addNameToCurrentUserProfile(_ name: DBPUIUserProfileName) -> Bool { false }
    func setNameAtIndexInCurrentUserProfile(_ payload: DataBrokerProtection.DBPUINameAtIndex) -> Bool { false }
    func removeNameAtIndexFromUserProfile(_ index: DataBrokerProtection.DBPUIIndex) -> Bool { false }
    func setBirthYearForCurrentUserProfile(_ year: DataBrokerProtection.DBPUIBirthYear) -> Bool { false }
    func addAddressToCurrentUserProfile(_ address: DataBrokerProtection.DBPUIUserProfileAddress) -> Bool { false }
    func setAddressAtIndexInCurrentUserProfile(_ payload: DataBrokerProtection.DBPUIAddressAtIndex) -> Bool { false }
    func removeAddressAtIndexFromUserProfile(_ index: DataBrokerProtection.DBPUIIndex) -> Bool { false }
    func startScanAndOptOut() -> Bool { false }

    func getInitialScanState() async -> DataBrokerProtection.DBPUIInitialScanState {
        DBPUIInitialScanState(resultsFound: [], scanProgress: .init(currentScans: 0, totalScans: 0, scannedBrokers: []))
    }

    func getMaintananceScanState() async -> DataBrokerProtection.DBPUIScanAndOptOutMaintenanceState {
        DBPUIScanAndOptOutMaintenanceState(
            inProgressOptOuts: [],
            completedOptOuts: [],
            scanSchedule: .init(lastScan: .init(date: 2, dataBrokers: []), nextScan: .init(date: 2, dataBrokers: [])),
            scanHistory: .init(sitesScanned: 2)
        )
    }

    func getDataBrokers() async -> [DataBrokerProtection.DBPUIDataBroker] {
        []
    }

    func getBackgroundAgentMetadata() async -> DataBrokerProtection.DBPUIDebugMetadata {
        DBPUIDebugMetadata(lastRunAppVersion: "")
    }

    func openSendFeedbackModal() async {}
}

private final class MockWebSettings: DataBrokerProtectionWebUIURLSettingsRepresentable {
    var customURL: String?
    var productionURL: String = ""
    var selectedURL: String = ""
    var selectedURLType: DataBrokerProtection.DataBrokerProtectionWebUIURLType = .production
    var selectedURLHostname: String = ""

    func setCustomURL(_ url: String) {}
    func setURLType(_ type: DataBrokerProtection.DataBrokerProtectionWebUIURLType) {}
}
