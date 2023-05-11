//
//  NetworkProtectionInviteCodeView.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import NetworkProtection
import SwiftUIExtensions

struct NetworkProtectionInviteCodeView: View {
    @ObservedObject var model: NetworkProtectionInviteViewModel

    var body: some View {
        Dialog {
            VStack(spacing: 20) {
                Image("InviteLock")
                Text(UserText.networkProtectionInviteDialogTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                Text(UserText.networkProtectionInviteDialogMessage)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                TextField(UserText.networkProtectionInviteFieldPrompt, text: $model.text)
                    .frame(width: 77)
                    .textFieldStyle(.roundedBorder)
                if let errorText = model.errorText {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundColor(Color("AlertRedLightDefaultText"))
                        .multilineTextAlignment(.center)
                }
            }
        } buttons: {
            Button(UserText.cancel) {
                model.cancel()
            }
            Button(UserText.continue) {
                Task {
                    await model.submit()
                }
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 320)
    }
}

struct NetworkProtectionInviteCodeView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkProtectionInviteCodeView(model: NetworkProtectionInviteViewModel(delegate: NetworkProtectionInvitePresenter(), redemptionCoordinator: NetworkProtectionCodeRedemptionCoordinator()))
    }
}
