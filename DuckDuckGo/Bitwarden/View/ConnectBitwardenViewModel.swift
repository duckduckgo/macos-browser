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

        var confirmButtonTitle: String {
            switch self {
            case .disclaimer, .lookingForBitwarden, .bitwardenFound: return "Next"
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
    
    private let bitwardenInstallationService: BitwardenInstallationManager
    private let bitwardenManager: BitwardenManagement
    
    private var bitwardenManagerStatusCancellable: AnyCancellable?
    
    init(bitwardenInstallationService: BitwardenInstallationManager, bitwardenManager: BitwardenManagement) {
        self.bitwardenInstallationService = bitwardenInstallationService
        self.bitwardenManager = bitwardenManager
        
        self.bitwardenManagerStatusCancellable = bitwardenManager.statusPublisher.sink { status in
            // TODO: Use this to change the view state, such as when the user grants permission for us to connect.
        }
    }
    
    func process(action: ViewAction) {
        switch action {
        case .confirm:
            if viewState == .connectedToBitwarden {
                delegate?.connectBitwardenViewModelDismissedView(self)
            } else {
                self.viewState = nextState(for: viewState)
            }
        case .cancel:
            delegate?.connectBitwardenViewModelDismissedView(self)
        case .openBitwarden:
            bitwardenInstallationService.openBitwarden()
        case .openBitwardenProductPage:
            NSWorkspace.shared.open(Constants.bitwardenAppStoreURL)
        }
    }
    
    private func nextState(for currentState: ViewState) -> ViewState {
        switch currentState {
        case .disclaimer:
            if bitwardenInstallationService.isBitwardenInstalled {
                return nextState(for: .bitwardenFound)
            } else {
                return .lookingForBitwarden
            }
        case .lookingForBitwarden:
            return .bitwardenFound
        case .bitwardenFound:
            // TODO: Update this to listen for when permission is granted.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.viewState = .connectToBitwarden
            }
            
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
