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
    var manager: PasswordManagerCoordinator
    let didFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(.bitwardenLogin)

            VStack(spacing: 2) {
                Text(UserText.passwordManagerPopoverTitle(managerName: manager.displayName))
                HStack(spacing: 3) {
                    Text(UserText.passwordManagerPopoverChangeInSettingsLabel)
                    Button {
                        WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .autofill)
                        didFinish()
                    } label: {
                        Text(UserText.passwordManagerPopoverSettingsButton)
                    }.buttonStyle(.link)
                }
            }
            if let email = manager.username {
                Text(UserText.passwordManagerPopoverConnectedToUser(user: email))
                    .font(.subheadline)
                    .foregroundColor(Color(.blackWhite60))
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
    static var previews: some View {
        PasswordManagementBitwardenItemView(manager: PasswordManagerCoordinator.shared, didFinish: {})
    }
}
