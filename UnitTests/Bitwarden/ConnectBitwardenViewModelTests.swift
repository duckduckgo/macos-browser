//
//  ConnectBitwardenViewModelTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

final class ConnectBitwardenViewModelTests: XCTestCase {

    func testWhenCreatingViewModel_ThenStatusIsDisclaimer() throws {
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenManager: bitwardenManager)

        XCTAssertEqual(viewModel.viewState, .disclaimer)
    }

    func testWhenViewModelIsOnDisclaimer_AndBitwardenIsNotInstalled_AndNextIsClicked_ThenViewStateIsLookingForBitwarden() {
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenManager: bitwardenManager)

        XCTAssertEqual(viewModel.viewState, .disclaimer)
        viewModel.process(action: .confirm)
        XCTAssertEqual(viewModel.viewState, .lookingForBitwarden)
    }

    func testWhenBitwardenIsInstalled_ThenViewStateIsWaitingForConnectionPermission() {
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenManager: bitwardenManager)

        XCTAssertEqual(viewModel.viewState, .disclaimer)
        viewModel.process(action: .confirm)

        let expectation = expectation(description: "status changed to waitingForConnectionPermission")
        let c = viewModel.$viewState.sink { viewState in
            if viewState == .waitingForConnectionPermission {
                expectation.fulfill()
            }
        }

        XCTAssertEqual(viewModel.viewState, .lookingForBitwarden)
        bitwardenManager.status = .notRunning

        waitForExpectations(timeout: 1)
        withExtendedLifetime(c) {}
    }

    func testWhenViewModelIsInConnectToBitwardenState_AndNextIsClicked_ThenHandshakeIsSent() {
        let bitwardenManager = MockBitwardenManager()

        bitwardenManager.status = .missingHandshake

        let viewModel = ConnectBitwardenViewModel(bitwardenManager: bitwardenManager)

        XCTAssertFalse(bitwardenManager.handshakeSent)

        XCTAssertEqual(viewModel.viewState, .connectToBitwarden)
        viewModel.process(action: .confirm)

        XCTAssertTrue(bitwardenManager.handshakeSent)
    }

    func testWhenViewModelReceivesConnectStateFromManager_ThenViewStateIsConnectedToBitwarden() {
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenManager: bitwardenManager)

        XCTAssertEqual(viewModel.viewState, .disclaimer)

        let vault = BWVault(id: "id", email: "dax@duck.com", status: .unlocked, active: true)
        bitwardenManager.status = .connected(vault: vault)

        XCTAssertEqual(viewModel.viewState, .connectedToBitwarden)
    }

}

class MockBitwardenManager: BWManagement {

    var handshakeSent = false
    // var bitwardenStatus = BitwardenStatus.disabled

    @Published var status: BWStatus = .disabled
    var statusPublisher: Published<BWStatus>.Publisher { $status }

    func initCommunication() {
        // no-op
    }

    func sendHandshake() {
        handshakeSent = true
    }

    func refreshStatusIfNeeded() {
        // no-op
    }

    func cancelCommunication() {
        // no-op
    }

    func openBitwarden() {
        // no-op
    }

    func retrieveCredentials(for url: URL, completion: @escaping ([BWCredential], BWError?) -> Void) {
        // no-op
    }

    func create(credential: BWCredential, completion: @escaping (BWError?) -> Void) {
        // no-op
    }

    func update(credential: BWCredential, completion: @escaping (BWError?) -> Void) {
        // no-op
    }

}
