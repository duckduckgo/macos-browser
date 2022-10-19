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
    
    func testWhenViewModelIsOnDisclaimer_AndBitwardenIsInstalled_AndNextIsClicked_ThenViewStateIsWaitingForConnectionPermission() {
        let installationManager = MockBitwardenInstallationManager()
        installationManager.isInstalled = true

        let bitwardenManager = MockBitwardenManager()
        let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: installationManager, bitwardenManager: bitwardenManager)
        
        XCTAssertEqual(viewModel.viewState, .disclaimer)
        viewModel.process(action: .confirm)
        XCTAssertEqual(viewModel.viewState, .waitingForConnectionPermission)
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
    
    @Published private(set) var status: BitwardenStatus = .disabled
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
