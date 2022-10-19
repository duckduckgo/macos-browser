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
        let installationManager = MockBitwardenInstallationManager()
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager, bitwardenManager: bitwardenManager)
        
        XCTAssertEqual(viewModel.viewState, .disclaimer)
    }
    
    func testWhenViewModelIsOnDisclaimer_AndBitwardenIsNotInstalled_AndNextIsClicked_ThenViewStateIsLookingForBitwarden() {
        let installationManager = MockBitwardenInstallationManager()
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager, bitwardenManager: bitwardenManager)
        
        XCTAssertEqual(viewModel.viewState, .disclaimer)
        viewModel.process(action: .confirm)
        XCTAssertEqual(viewModel.viewState, .lookingForBitwarden)
    }
    
    func testWhenViewModelIsLookingForBitwarden_AndBitwardenIsThenInstalled_ThenViewStateIsBitwardenFound() {
        let installationManager = MockBitwardenInstallationManager()
        installationManager.isInstalled = false

        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager,
                                                  bitwardenManager: bitwardenManager,
                                                  bitwardenInstallationCheckInterval: 0.1)
        
        XCTAssertEqual(viewModel.viewState, .disclaimer)
        viewModel.process(action: .confirm)
        XCTAssertEqual(viewModel.viewState, .lookingForBitwarden)
        
        installationManager.isInstalled = true
        
        let predicate = NSPredicate { _, _ in
            return viewModel.viewState == .bitwardenFound
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: .none)
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testWhenViewModelIsOnDisclaimer_AndBitwardenIsInstalled_AndNextIsClicked_ThenViewStateIsWaitingForConnectionPermission() {
        let installationManager = MockBitwardenInstallationManager()
        installationManager.isInstalled = true

        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager, bitwardenManager: bitwardenManager)
        
        XCTAssertEqual(viewModel.viewState, .disclaimer)
        viewModel.process(action: .confirm)
        XCTAssertEqual(viewModel.viewState, .waitingForConnectionPermission)
    }
    
    func testWhenViewModelIsInConnectToBitwardenState_AndNextIsClicked_ThenHandshakeIsSent() {
        let installationManager = MockBitwardenInstallationManager()
        let bitwardenManager = MockBitwardenManager()
 
        installationManager.isInstalled = true
        bitwardenManager.status = .approachable

        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager, bitwardenManager: bitwardenManager)
        
        XCTAssertFalse(bitwardenManager.handshakeSent)
        
        XCTAssertEqual(viewModel.viewState, .disclaimer)
        viewModel.process(action: .confirm)
        XCTAssertEqual(viewModel.viewState, .connectToBitwarden)
        viewModel.process(action: .confirm)
        
        XCTAssertTrue(bitwardenManager.handshakeSent)
    }
    
    func testWhenViewModelReceivesConnectStateFromManager_ThenViewStateIsConnectedToBitwarden() {
        let installationManager = MockBitwardenInstallationManager()
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager, bitwardenManager: bitwardenManager)
        
        XCTAssertEqual(viewModel.viewState, .disclaimer)
        
        let vault = BitwardenStatus.Vault(id: "id", email: "dax@duck.com", status: .unlocked, active: true)
        bitwardenManager.status = .connected(vault: vault)
        
        XCTAssertEqual(viewModel.viewState, .connectedToBitwarden)
    }
    
    func testWhenClickingOpenBitwardenButton_ThenBitwardenIsOpened() {
        let installationManager = MockBitwardenInstallationManager()
        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager, bitwardenManager: bitwardenManager)
        
        XCTAssertFalse(installationManager.bitwardenOpened)
        viewModel.process(action: .openBitwarden)
        XCTAssertTrue(installationManager.bitwardenOpened)
    }

}

class MockBitwardenInstallationManager: BitwardenInstallationManager {
    
    var isInstalled = false
    var bitwardenOpened = false
    
    var isBitwardenInstalled: Bool {
        return isInstalled
    }
    
    func openBitwarden() -> Bool {
        bitwardenOpened = true
        return true
    }
    
}

class MockBitwardenManager: BitwardenManagement {

    var handshakeSent = false
    // var bitwardenStatus = BitwardenStatus.disabled
    
    @Published var status: BitwardenStatus = .disabled
    var statusPublisher: Published<BitwardenStatus>.Publisher { $status }
    
    func sendHandshake() {
        handshakeSent = true
    }
    
    func retrieveCredentials(for url: URL, completion: @escaping ([BitwardenCredential], BitwardenError?) -> Void) {
        // no-op
    }
    
    func create(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        // no-op
    }
    
    func update(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        // no-op
    }
    
    
}
