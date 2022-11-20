//
//  ConnectBitwardenViewModel.swift
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

import Foundation
import Combine
import os.log

protocol ConnectBitwardenViewModelDelegate: AnyObject {
    
    func connectBitwardenViewModelDismissedView(_ viewModel: ConnectBitwardenViewModel, canceled: Bool)
    
}

final class ConnectBitwardenViewModel: ObservableObject {
    
    enum ViewState {
        
        // Initial state:
        case disclaimer
        
        // Bitwarden installation:
        case lookingForBitwarden
        case oldVersion
        case bitwardenFound
        
        // Bitwarden connection:
        case waitingForConnectionPermission
        case connectToBitwarden
        
        // Final state:
        case connectedToBitwarden
        
        var canContinue: Bool {
            switch self {
            case .lookingForBitwarden, .oldVersion, .waitingForConnectionPermission: return false
            default: return true
            }
        }
        
        var confirmButtonTitle: String {
            switch self {
            case .disclaimer, .lookingForBitwarden, .oldVersion, .bitwardenFound: return "Next"
            case .waitingForConnectionPermission, .connectToBitwarden: return "Connect"
            case .connectedToBitwarden: return "OK"
            }
        }
        
        var cancelButtonVisible: Bool {
            return self != .connectedToBitwarden
        }
        
    }
    
    enum ViewAction {
        case cancel
        case confirm
        case openBitwarden
        case openBitwardenProductPage
    }
    
    private enum Constants {
        static let bitwardenAppStoreURL = URL(string: "https://apps.apple.com/us/app/bitwarden/id1352778147")!
    }
    
    weak var delegate: ConnectBitwardenViewModelDelegate?
    
    @Published private(set) var viewState: ViewState = .disclaimer
    @Published private(set) var error: Error?

    private let bitwardenManager: BitwardenManagement
    
    private var bitwardenManagerStatusCancellable: AnyCancellable?

    init(bitwardenManager: BitwardenManagement) {
        self.bitwardenManager = bitwardenManager
        self.bitwardenManagerStatusCancellable = bitwardenManager.statusPublisher.sink { [weak self] status in
            self?.adjustViewState(status: status)
        }
    }

    func adjustViewState(status: BitwardenStatus) {
        switch status {
        case .disabled:
            self.viewState = .disclaimer
        case .notInstalled:
            self.viewState = .lookingForBitwarden
        case .oldVersion:
            self.viewState = .oldVersion
        case .notRunning:
            self.viewState = .waitingForConnectionPermission
        case .integrationNotApproved:
            self.viewState = .waitingForConnectionPermission
        case .missingHandshake:
            self.viewState = .connectToBitwarden
        case .waitingForHandshakeApproval:
            self.viewState = .connectToBitwarden
        case .handshakeNotApproved:
            self.viewState = .connectToBitwarden
        case .connecting:
            self.viewState = .connectToBitwarden
        case .waitingForStatusResponse:
            self.viewState = .connectedToBitwarden
        case .connected(vault: _):
            self.viewState = .connectedToBitwarden
        case .error(error: let error):
            self.error = error
        }
    }

    func process(action: ViewAction) {
        switch action {
        case .confirm:
            if viewState == .connectedToBitwarden {
                delegate?.connectBitwardenViewModelDismissedView(self, canceled: false)
            } else if viewState == .connectToBitwarden {
                bitwardenManager.sendHandshake()
                bitwardenManager.openBitwarden()
            }
            
        case .cancel:
            delegate?.connectBitwardenViewModelDismissedView(self, canceled: true)
            
        case .openBitwarden:
            bitwardenManager.openBitwarden()
            
        case .openBitwardenProductPage:
            NSWorkspace.shared.open(Constants.bitwardenAppStoreURL)
        }
    }
}
