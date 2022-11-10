//
//  PasswordManagementBitwardenItemView.swift
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

import SwiftUI

struct PasswordManagementBitwardenItemView: View {
    @ObservedObject var manager: BitwardenSecureVaultViewManager
    let didFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image("BitwardenLogin")
            
            VStack(spacing: 2) {
                Text("You're using Bitwarden to manage passwords")
                HStack (spacing: 3) {
                    Text("Change in")
                    Button {
                        manager.openSettings()
                        didFinish()
                    } label: {
                        Text("Settings")
                    }.buttonStyle(.link)
                    
                }
            }
            if let email = manager.email {
                Text("Connected to user \(email)")
                    .font(.caption)
            }
            
            Button {
                manager.openBitwarden()
                didFinish()
            } label: {
                Text("Open Bitwarden")
            }
        }
    }
}

struct PasswordManagementBitwardenItemView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordManagementBitwardenItemView(manager: BitwardenSecureVaultViewManager()) { }
    }
}

final class BitwardenSecureVaultViewManager: ObservableObject {
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
        bitwardenManager.status.isConnected
    }
    
    var status: BitwardenVault.Status {
        guard let vault = vault  else { return .locked }
        return vault.status
    }
    
    var email: String? {
        guard let vault = vault  else { return nil }
        return vault.email
    }
    
    func openBitwarden() {
        bitwardenManager.openBitwarden()
    }
    
    func openSettings() {
        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .autofill)
    }
}
