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

protocol ConnectBitwardenViewModelDelegate: AnyObject {
    
    func connectBitwardenViewModelDismissedView(_ viewModel: ConnectBitwardenViewModel)
    
}

final class ConnectBitwardenViewModel: ObservableObject {
    
    enum ViewState {
        // Initial state:
        case disclaimer
        
        // Bitwarden installation:
        case lookingForBitwarden
        case bitwardenFound
        
        // Bitwarden connection:
        case waitingForConnectionPermission
        case connectToBitwarden
        
        // Final state:
        case connectedToBitwarden
        
        var canContinue: Bool {
            switch self {
            case .lookingForBitwarden, .waitingForConnectionPermission: return false
            default: return true
            }
        }
    }
    
    enum ViewAction {
        case cancel
        case confirm
        case openBitwardenProductPage
    }
    
    weak var delegate: ConnectBitwardenViewModelDelegate?
    
    @Published private(set) var viewState: ViewState
    
    private let bitwardenInstallationService: BitwardenInstallationManager
    
    init(bitwardenInstallationService: BitwardenInstallationManager) {
        self.bitwardenInstallationService = bitwardenInstallationService
        self.viewState = .disclaimer
    }
    
    func process(action: ViewAction) {
        switch action {
        case .confirm:
            self.viewState = nextState(for: viewState)
        case .cancel:
            delegate?.connectBitwardenViewModelDismissedView(self)
        case .openBitwardenProductPage:
            let bitwardenURL = URL(string: "https://apps.apple.com/us/app/bitwarden/id1352778147")!
            NSWorkspace.shared.open(bitwardenURL)
        }
    }
    
    private func nextState(for currentState: ViewState) -> ViewState {
        switch currentState {
        case .disclaimer:
            if bitwardenInstallationService.isBitwardenInstalled {
                return .bitwardenFound
            } else {
                return .lookingForBitwarden
            }
        case .lookingForBitwarden:
            return .bitwardenFound
        case .bitwardenFound:
            return .waitingForConnectionPermission
        case .waitingForConnectionPermission:
            return .connectToBitwarden
        case .connectToBitwarden:
            return .connectedToBitwarden
        case .connectedToBitwarden:
            return .connectedToBitwarden
        }
    }
    
}
