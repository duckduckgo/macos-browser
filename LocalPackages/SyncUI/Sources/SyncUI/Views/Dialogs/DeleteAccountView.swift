//
//  DeleteAccountView.swift
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
import SwiftUIExtensions

struct DeleteAccountView: View {

    @EnvironmentObject var model: ManagementDialogModel

    let devices: [SyncDevice]

    var body: some View {
        SyncDialog {
            VStack(spacing: 20.0) {
                Image(.syncRemoveDeviceDesktop)
                SyncUIViews.TextHeader(text: UserText.deleteAccountTitle)
                SyncUIViews.TextDetailMultiline(text: UserText.deleteAccountMessage)
            }

            ScrollView {
                SyncedDevicesList(devices: devices)
                    .roundedBorder()
            }

        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }
            .buttonStyle(DismissActionButtonStyle())
            Button(UserText.deleteAccountButton) {
                model.delegate?.deleteAccount()
            }
            .buttonStyle(DestructiveActionButtonStyle(enabled: true))
        }
        .frame(width: 360,
               // Grow with the number of devices, up to a point
               height: min(410, 272 + (CGFloat(devices.count) * 44)))
    }

}
