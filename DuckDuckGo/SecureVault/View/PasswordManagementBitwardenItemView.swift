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

import BrowserServicesKit
import SwiftUI

struct PasswordManagementBitwardenItemView: View {
    var manager: PasswordManagerCoordinating
    let windowManager: WindowManagerProtocol?
    let didFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image("BitwardenLogin")

            VStack(spacing: 2) {
                Text(UserText.passwordManagerPopoverTitle(managerName: manager.displayName))
                HStack (spacing: 3) {
                    Text(UserText.passwordManagerPopoverChangeInSettingsLabel)
                    Button {
                        windowManager?.showPreferencesTab(withSelectedPane: .autofill)
                        didFinish()
                    } label: {
                        Text(UserText.passwordManagerPopoverSettingsButton)
                    }.buttonStyle(.link)
                }
            }
            if let email = manager.username {
                Text(UserText.passwordManagerPopoverConnectedToUser(user: email))
                    .font(.subheadline)
                    .foregroundColor(Color("BlackWhite60"))
            }

            Button {
                manager.openPasswordManager()
                didFinish()
            } label: {
                Text(UserText.openPasswordManagerButton(managerName: manager.displayName))
            }
        }
    }
}

struct PasswordManagementBitwardenItemView_Previews: PreviewProvider {

    final class PasswordManagerCoordinatorPreview: PasswordManagerCoordinating {
        var displayName: String {
            "Display Name"
        }

        var username: String? {
            "example.username@duck.com"
        }

        func openPasswordManager() {
        }

        var isEnabled: Bool {
            true
        }

        var name: String {
            "Name"
        }

        var isLocked: Bool {
            false
        }

        var activeVaultEmail: String? {
            nil
        }

        var bitwardenManagement: BWManagement {
            fatalError()
        }

        func accountsFor(domain: String, completion: @escaping ([SecureVaultModels.WebsiteAccount], Error?) -> Void) {
            completion([], nil)
        }

        func cachedAccountsFor(domain: String) -> [SecureVaultModels.WebsiteAccount] {
            []
        }

        func cachedWebsiteCredentialsFor(domain: String, username: String) -> SecureVaultModels.WebsiteCredentials? {
            nil
        }

        func websiteCredentialsFor(accountId: String, completion: @escaping (SecureVaultModels.WebsiteCredentials?, Error?) -> Void) {
            completion(nil, nil)
        }

        func websiteCredentialsFor(domain: String, completion: @escaping ([SecureVaultModels.WebsiteCredentials], Error?) -> Void) {
            completion([], nil)
        }

        func askToUnlock(completionHandler: @escaping () -> Void) {
            completionHandler()
        }

        func storeWebsiteCredentials(_ credentials: SecureVaultModels.WebsiteCredentials, completion: @escaping (Error?) -> Void) {
            completion(nil)
        }

    }

    static var previews: some View {
        PasswordManagementBitwardenItemView(manager: PasswordManagerCoordinatorPreview(), windowManager: nil, didFinish: {})
    }
}
