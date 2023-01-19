//
//  NetworkProtectionStatusViewModelTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

class NetworkProtectionStatusViewModelTests: XCTestCase {

    // MARK: - Testing Support

    /// Mock  class to aid in testing
    ///
    private class MockNetworkProtection: NetworkProtectionProvider {
        private var connected: Bool = false

        var startCallback: (() -> Void)?
        var stopCallback: (() -> Void)?

        init(initialStatus: NetworkProtectionConnectionStatus = .unknown) {
            statusChangePublisher = CurrentValueSubject<NetworkProtectionConnectionStatus, Never>(initialStatus)
        }

        func isConnected() async -> Bool {
            connected
        }

        func start() async throws {
            startCallback?()
        }

        func stop() async throws {
            stopCallback?()
        }

        let configChangePublisher = CurrentValueSubject<Void, Never>(())
        let statusChangePublisher: CurrentValueSubject<NetworkProtectionConnectionStatus, Never>
    }

    // MARK: - Tests

    /// We expect that the model will be initialized correctly (with status .uknown by default).
    ///
    func testProperInitialization() async throws {
        let networkProtection = MockNetworkProtection()
        let model = NetworkProtectionStatusView.Model(networkProtection: networkProtection)

        let isRunning = await model.isRunning.wrappedValue
        XCTAssertFalse(isRunning)
        XCTAssertEqual(model.connectionStatusDescription, UserText.networkProtectionStatusUnknown)
        XCTAssertEqual(model.timeLapsed, UserText.networkProtectionStatusViewTimerZero)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOff)
        XCTAssertFalse(model.showServerDetails)
    }

    /// We expect the model to properly reflect the disconnected status.
    ///
    func testProperlyReflectsStatusDisconnected() async throws {
        let networkProtection = MockNetworkProtection(initialStatus: .disconnected)
        let model = NetworkProtectionStatusView.Model(networkProtection: networkProtection)

        let isRunning = await model.isRunning.wrappedValue
        XCTAssertFalse(isRunning)
        XCTAssertEqual(model.connectionStatusDescription, UserText.networkProtectionStatusDisconnected)
        XCTAssertEqual(model.timeLapsed, UserText.networkProtectionStatusViewTimerZero)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOff)
        XCTAssertFalse(model.showServerDetails)
    }

    /// We expect the model to properly reflect the connected status.
    ///
    func testProperlyReflectsStatusDisconnecting() async throws {
        let mockServerIP = "127.0.0.1"
        let mockDate = Date().addingTimeInterval(-59)
        let mockDateString = "00:00:59"

        let networkProtection = MockNetworkProtection(initialStatus: .disconnecting(connectedDate: mockDate, serverAddress: mockServerIP))
        let model = NetworkProtectionStatusView.Model(networkProtection: networkProtection)

        XCTAssertEqual(model.connectionStatusDescription, UserText.networkProtectionStatusDisconnecting)
        XCTAssertEqual(model.timeLapsed, mockDateString)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOn)
        XCTAssertTrue(model.showServerDetails)
        XCTAssertEqual(model.serverAddress, mockServerIP)
        XCTAssertEqual(model.serverLocation, "Los Angeles, United States")
    }

    /// We expect the model to properly reflect the connected status.
    ///
    func testProperlyReflectsStatusConnected() async throws {
        let mockServerIP = "127.0.0.1"
        let mockDate = Date().addingTimeInterval(-59)
        let mockDateString = "00:00:59"

        let networkProtection = MockNetworkProtection(initialStatus: .connected(connectedDate: mockDate, serverAddress: mockServerIP))
        let model = NetworkProtectionStatusView.Model(networkProtection: networkProtection)

        let isRunning = await model.isRunning.wrappedValue
        XCTAssertTrue(isRunning)
        XCTAssertTrue(model.connectionStatusDescription.hasPrefix(UserText.networkProtectionStatusConnected))
        XCTAssertEqual(model.timeLapsed, mockDateString)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOn)
        XCTAssertTrue(model.showServerDetails)
        XCTAssertEqual(model.serverAddress, mockServerIP)
        XCTAssertEqual(model.serverLocation, "Los Angeles, United States")
    }

    /// We expect the model to properly reflect the connecting status.
    ///
    func testProperlyReflectsStatusConnecting() async throws {
        let networkProtection = MockNetworkProtection(initialStatus: .connecting)
        let model = NetworkProtectionStatusView.Model(networkProtection: networkProtection)

        XCTAssertEqual(model.connectionStatusDescription, UserText.networkProtectionStatusConnecting)
        XCTAssertEqual(model.timeLapsed, UserText.networkProtectionStatusViewTimerZero)
        XCTAssertEqual(model.featureStatusDescription, UserText.networkProtectionStatusViewFeatureOff)
        XCTAssertFalse(model.showServerDetails)
    }

    /// We expect that setting the model's `isRunning` to `true`, will start network protection.
    ///
    func testStartsNetworkProtection() async throws {
        let networkProtection = MockNetworkProtection()
        let model = NetworkProtectionStatusView.Model(networkProtection: networkProtection)
        let networkProtectionWasStarted = expectation(description: "The model started network protection when appropriate")

        networkProtection.startCallback = {
            networkProtectionWasStarted.fulfill()
        }

        Task { @MainActor in
            model.isRunning.wrappedValue = true
        }

        let waiter = XCTWaiter()
        waiter.wait(for: [networkProtectionWasStarted], timeout: 0.1)
    }

    /// We expect that setting the model's `isRunning` to `false`, will stop network protection.
    ///
    func testStopsNetworkProtection() async throws {
        let mockServerIP = "127.0.0.1"

        let networkProtection = MockNetworkProtection(initialStatus: .connected(connectedDate: Date(), serverAddress: mockServerIP))
        let model = NetworkProtectionStatusView.Model(networkProtection: networkProtection)

        let networkProtectionWasStopped = expectation(description: "The model stopped network protection when appropriate")

        networkProtection.stopCallback = {
            networkProtectionWasStopped.fulfill()
        }

        Task { @MainActor in
            model.isRunning.wrappedValue = false
        }

        // await waitForExpectations(timeout:) doesn't work very well with publishers
        // I found that using a waiter works well as an alternative
        let waiter = XCTWaiter()
        waiter.wait(for: [networkProtectionWasStopped], timeout: 0.1)
    }
}
