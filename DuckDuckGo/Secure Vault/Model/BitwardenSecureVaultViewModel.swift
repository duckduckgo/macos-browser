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
    private let managerCoordinator: PasswordManagerCoordinator
    
    internal init(managerCoordinator: PasswordManagerCoordinator) {
        self.managerCoordinator = managerCoordinator
    }
    
    var isConnected: Bool {
        managerCoordinator.isEnabled
    }
    
    var status: ExternalPasswordManagerStatus {
        if managerCoordinator.isLocked {
            return .locked
        }
        return .unlocked
    }
    
    var username: String? {
        managerCoordinator.username
    }
    
    var managerName: String {
        managerCoordinator.displayName
    }
    
    func openExternalPasswordManager() {
        managerCoordinator.openPasswordManager()
    }
    
    func openSettings() {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .autofill)
    }
}
