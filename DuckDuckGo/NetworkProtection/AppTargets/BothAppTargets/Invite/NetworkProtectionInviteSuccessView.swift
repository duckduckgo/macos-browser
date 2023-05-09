//
//  NetworkProtectionSuccessView.swift
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

struct NetworkProtectionInviteSuccessView: View {
    @ObservedObject var model: NetworkProtectionInviteViewModel

    var body: some View {
        Dialog {
            VStack(spacing: 20) {
                Image("InviteLockSuccess")
                Text(UserText.networkProtectionInviteSuccessTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                Text(UserText.networkProtectionInviteSuccessMessage).font(.system(size: 13)).multilineTextAlignment(.center)
            }
        } buttons: {
            Button(UserText.inviteDialogGetStartedButton) {
                model.getStarted()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 320)
    }
}

struct NetworkProtectionSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkProtectionInviteSuccessView(model: NetworkProtectionInviteViewModel(delegate: NetworkProtectionInvitePresenter(), redemptionCoordinator: NetworkProtectionCodeRedemptionCoordinator()))
    }
}
