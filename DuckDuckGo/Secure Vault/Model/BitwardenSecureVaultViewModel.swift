//
//  BitwardenSecureVaultViewModel.swift
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

enum ExternalPasswordManagerStatus: String {
    case locked
    case unlocked
}

protocol ExternalPasswordManagerViewModel {
    var isConnected: Bool { get }
    var username: String? { get }
    var managerName: String { get }
    var status: ExternalPasswordManagerStatus { get }
    
    func openExternalPasswordManager()
    func openSettings()
}

final class BitwardenSecureVaultViewModel: ExternalPasswordManagerViewModel, ObservableObject {
    private let bitwardenManager: BitwardenManager
    
    internal init(bitwardenManager: BitwardenManager = .shared) {
        self.bitwardenManager = bitwardenManager
    }
    
    private var vault: BitwardenVault? {
        if case let .connected(vault: vault) = bitwardenManager.status {
            return vault
        }
       return nil
    }
    
    var isConnected: Bool {
        switch bitwardenManager.status {
        case .connected(vault: _), .notRunning:
            return true
        default:
            return false
        }
    }
    
    var status: ExternalPasswordManagerStatus {
        guard let vault = vault  else { return .locked }
        
        switch vault.status {
        case .locked:
            return .locked
        case .unlocked:
            return .unlocked
        }
    }
    
    var username: String? {
        guard let vault = vault  else { return nil }
        return vault.email
    }
    
    var managerName: String {
        "Bitwarden"
    }
    
    func openExternalPasswordManager() {
        bitwardenManager.openBitwarden()
    }
    
    func openSettings() {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .autofill)
    }
}
