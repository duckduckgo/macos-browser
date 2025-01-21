//
//  TunnelControllerViewModelTests.swift
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
import Combine
import SwiftUI
import XCTest
import NetworkProtection
@testable import NetworkProtectionUI
import NetworkProtectionTestUtils

final class TunnelControllerViewModelTests: XCTestCase {

    private class MockStatusReporter: NetworkProtectionStatusReporter {
        static let defaultServerInfo = NetworkProtectionStatusServerInfo(
            serverLocation: TunnelControllerViewModelTests.serverAttributes(),
            serverAddress: "127.0.0.1")

        let statusObserver: ConnectionStatusObserver
        let serverInfoObserver: ConnectionServerInfoObserver
        let connectionErrorObserver: ConnectionErrorObserver
        let connectivityIssuesObserver: ConnectivityIssueObserver
        let controllerErrorMessageObserver: ControllerErrorMesssageObserver
        let dataVolumeObserver: DataVolumeObserver
        let knownFailureObserver: KnownFailureObserver

        init(status: ConnectionStatus,
             isHavingConnectivityIssues: Bool = false,
             serverInfo: NetworkProtectionStatusServerInfo = MockStatusReporter.defaultServerInfo,
             tunnelErrorMessage: String? = nil,
             controllerErrorMessage: String? = nil,
             dataVolume: DataVolume = .init(),
             failure: KnownFailure? = nil) {

            let mockStatusObserver = MockConnectionStatusObserver()
            mockStatusObserver.subject.send(status)
            statusObserver = mockStatusObserver

            let mockServerInfoObserver = MockConnectionServerInfoObserver()
            mockServerInfoObserver.subject.send(serverInfo)
            serverInfoObserver = mockServerInfoObserver

            let mockConnectivityIssueObserver = MockConnectivityIssueObserver()
            mockConnectivityIssueObserver.subject.send(isHavingConnectivityIssues)
            connectivityIssuesObserver = mockConnectivityIssueObserver

            let mockConnectionErrorObserver = MockConnectionErrorObserver()
            mockConnectionErrorObserver.subject.send(tunnelErrorMessage)
            connectionErrorObserver = mockConnectionErrorObserver

            let mockControllerErrorMessageObserver = MockControllerErrorMesssageObserver()
            mockControllerErrorMessageObserver.subject.send(controllerErrorMessage)
            controllerErrorMessageObserver = mockControllerErrorMessageObserver

            let mockDataVolumeObserver = MockDataVolumeObserver()
            mockDataVolumeObserver.subject.send(dataVolume)
            dataVolumeObserver = mockDataVolumeObserver

            let mockKnownFailureObserver = MockKnownFailureObserver()
            mockKnownFailureObserver.subject.send(failure)
            knownFailureObserver = mockKnownFailureObserver
        }

        func forceRefresh() {
            // Intentional no-op
        }
    }

    // MARK: - Testing Support

    /// Mock  class to aid in testing
    ///
    private class MockTunnelController: TunnelController {
        private var connected: Bool = false

        var startCallback: (() -> Void)?
        var stopCallback: (() -> Void)?

        var isConnected: Bool {
            connected
        }

        func start() async {
            startCallback?()
        }

        func stop() async {
            stopCallback?()
        }

        func command(_ command: VPNCommand) async throws {
            // no-op
        }
    }

    // MARK: - Tests

    /// We expect the model to properly reflect the disconnected status.
    ///
    @MainActor
    func testProperlyReflectsStatusDisconnected() async throws {
        let controller = MockTunnelController()
        let statusReporter = MockStatusReporter(status: .disconnected)
        let model = TunnelControllerViewModel(
            controller: controller,
            onboardingStatusPublisher: Just(OnboardingStatus.completed).eraseToAnyPublisher(),
            statusReporter: statusReporter,
            vpnSettings: .init(defaults: .standard),
            proxySettings: .init(defaults: .standard),
            locationFormatter: MockVPNLocationFormatter(),
            uiActionHandler: MockVPNUIActionHandler())

        let isToggleOn = model.isToggleOn.wrappedValue
        XCTAssertFalse(isToggleOn)
        XCTAssertEqual(model.connectionStatusDescription, UserText.networkProtectionStatusDisconnected)
        XCTAssertEqual(model.timeLapsed, UserText.networkProtectionStatusViewTimerZero)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOff)
        XCTAssertFalse(model.showServerDetails)
    }

    /// We expect the model to properly reflect the disconnecting status.
    ///
    @MainActor
    func testProperlyReflectsStatusDisconnecting() async throws {
        let controller = MockTunnelController()
        let statusReporter = MockStatusReporter(status: .disconnecting)
        let model = TunnelControllerViewModel(
            controller: controller,
            onboardingStatusPublisher: Just(OnboardingStatus.completed).eraseToAnyPublisher(),
            statusReporter: statusReporter,
            vpnSettings: .init(defaults: .standard),
            proxySettings: .init(defaults: .standard),
            locationFormatter: MockVPNLocationFormatter(),
            uiActionHandler: MockVPNUIActionHandler())

        XCTAssertEqual(model.connectionStatusDescription, UserText.networkProtectionStatusDisconnecting)
        XCTAssertEqual(model.timeLapsed, UserText.networkProtectionStatusViewTimerZero)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOn)
        XCTAssertFalse(model.showServerDetails)
        XCTAssertEqual(model.serverAddress, "Unknown")
        XCTAssertEqual(model.serverLocation, "Unknown...")
    }

    /// We expect the model to properly reflect the connected status.
    ///
    @MainActor
    func testProperlyReflectsStatusConnected() async throws {
        let mockServerIP = "127.0.0.1"
        let mockDate = Date().addingTimeInterval(-59)
        let mockDateString = "00:00:59"

        let controller = MockTunnelController()
        let serverInfo = NetworkProtectionStatusServerInfo(
            serverLocation: Self.serverAttributes(),
            serverAddress: mockServerIP)
        let statusReporter = MockStatusReporter(status: .connected(connectedDate: mockDate), serverInfo: serverInfo)
        let model = TunnelControllerViewModel(
            controller: controller,
            onboardingStatusPublisher: Just(OnboardingStatus.completed).eraseToAnyPublisher(),
            statusReporter: statusReporter,
            vpnSettings: .init(defaults: .standard),
            proxySettings: .init(defaults: .standard),
            locationFormatter: MockVPNLocationFormatter(),
            uiActionHandler: MockVPNUIActionHandler())

        let isToggleOn = model.isToggleOn.wrappedValue
        XCTAssertTrue(isToggleOn)
        XCTAssertTrue(model.connectionStatusDescription.hasPrefix(UserText.networkProtectionStatusConnected))
        XCTAssertEqual(model.timeLapsed, mockDateString)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOn)
        XCTAssertTrue(model.showServerDetails)
        XCTAssertEqual(model.serverAddress, mockServerIP)
        XCTAssertEqual(model.serverLocation, "El Segundo, United States...")
    }

    /// We expect the model to properly reflect the connecting status.
    ///
    @MainActor
    func testProperlyReflectsStatusConnecting() async throws {
        let controller = MockTunnelController()
        let statusReporter = MockStatusReporter(status: .connecting)
        let model = TunnelControllerViewModel(
            controller: controller,
            onboardingStatusPublisher: Just(OnboardingStatus.completed).eraseToAnyPublisher(),
            statusReporter: statusReporter,
            vpnSettings: .init(defaults: .standard),
            proxySettings: .init(defaults: .standard),
            locationFormatter: MockVPNLocationFormatter(),
            uiActionHandler: MockVPNUIActionHandler())

        XCTAssertEqual(model.connectionStatusDescription, UserText.networkProtectionStatusConnecting)
        XCTAssertEqual(model.timeLapsed, UserText.networkProtectionStatusViewTimerZero)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOff)
        XCTAssertFalse(model.showServerDetails)
    }

    /// We expect the model to properly reflect the data volume.
    ///
    @MainActor
    func testProperlyReflectsDataVolume() async throws {
        let controller = MockTunnelController()
        let statusReporter = MockStatusReporter(status: .connected(connectedDate: Date()),
                                                dataVolume: .init(bytesSent: 512000, bytesReceived: 1024000))
        let model = TunnelControllerViewModel(
            controller: controller,
            onboardingStatusPublisher: Just(OnboardingStatus.completed).eraseToAnyPublisher(),
            statusReporter: statusReporter,
            vpnSettings: .init(defaults: .standard),
            proxySettings: .init(defaults: .standard),
            locationFormatter: MockVPNLocationFormatter(),
            uiActionHandler: MockVPNUIActionHandler())

        XCTAssertEqual(model.formattedDataVolume, .init(dataSent: "512 KB", dataReceived: "1 MB"))
    }

    /// We expect that setting the model's `isRunning` to `true`, will start the VPN.
    ///
    @MainActor
    func testStartsNetworkProtection() async throws {
        let controller = MockTunnelController()
        let statusReporter = MockStatusReporter(status: .disconnected)
        let model = TunnelControllerViewModel(
            controller: controller,
            onboardingStatusPublisher: Just(OnboardingStatus.completed).eraseToAnyPublisher(),
            statusReporter: statusReporter,
            vpnSettings: .init(defaults: .standard),
            proxySettings: .init(defaults: .standard),
            locationFormatter: MockVPNLocationFormatter(),
            uiActionHandler: MockVPNUIActionHandler())
        let networkProtectionWasStarted = expectation(description: "The model started the VPN when appropriate")

        controller.startCallback = {
            networkProtectionWasStarted.fulfill()
        }

        Task { @MainActor in
            model.isToggleOn.wrappedValue = true
        }

        await fulfillment(of: [networkProtectionWasStarted], timeout: 0.1)
    }

    /// We expect that setting the model's `isRunning` to `false`, will stop the VPN.
    ///
    @MainActor
    func testStopsNetworkProtection() async throws {
        let mockDate = Date().addingTimeInterval(-59)
        let mockServerIP = "127.0.0.1"

        let controller = MockTunnelController()
        let serverInfo = NetworkProtectionStatusServerInfo(serverLocation: Self.serverAttributes(), serverAddress: mockServerIP)
        let statusReporter = MockStatusReporter(
            status: .connected(connectedDate: mockDate),
            serverInfo: serverInfo)
        let model = TunnelControllerViewModel(
            controller: controller,
            onboardingStatusPublisher: Just(OnboardingStatus.completed).eraseToAnyPublisher(),
            statusReporter: statusReporter,
            vpnSettings: .init(defaults: .standard),
            proxySettings: .init(defaults: .standard),
            locationFormatter: MockVPNLocationFormatter(),
            uiActionHandler: MockVPNUIActionHandler())

        let networkProtectionWasStopped = expectation(description: "The model stopped the VPN when appropriate")

        controller.stopCallback = {
            networkProtectionWasStopped.fulfill()
        }

        Task { @MainActor in
            model.isToggleOn.wrappedValue = false
        }

        await fulfillment(of: [networkProtectionWasStopped], timeout: 0.1)
    }

    fileprivate static func serverAttributes() -> NetworkProtectionServerInfo.ServerAttributes {
         let json = """
         {
             "city": "El Segundo",
             "country": "us",
             "latitude": 33.9192,
             "longitude": -118.4165,
             "region": "North America",
             "state": "ca",
             "tzOffset": -28800
         }
         """

         // swiftlint:disable:next force_try
         return try! JSONDecoder().decode(NetworkProtectionServerInfo.ServerAttributes.self, from: json.data(using: .utf8)!)
     }
}
