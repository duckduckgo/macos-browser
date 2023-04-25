//
//  RemoveDeviceView.swift
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

struct RemoveDeviceView: View {

    @EnvironmentObject var model: ManagementDialogModel

    let device: SyncDevice

    var body: some View {
        SyncDialog(spacing: 20.0) {

            Image("SyncRemoveDeviceDesktop")
            Text(UserText.removeDeviceConfirmTitle)
                .font(.system(size: 17, weight: .bold))
            Text(UserText.removeDeviceConfirmMessage(device.name))
                .multilineTextAlignment(.center)
                .font(.system(size: 13))

        } buttons: {

            Button(UserText.cancel) {
                model.endFlow()
            }

            Button(UserText.removeDeviceConfirmButton) {
                model.delegate?.removeDevice(device)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))

        }
        .frame(width: 360, height: 250)

    }

}
