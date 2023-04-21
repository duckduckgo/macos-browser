//
//  DeviceDetailsView.swift
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

struct DeviceDetailsView: View {

    @EnvironmentObject var model: ManagementDialogModel

    let device: SyncDevice

    @State var deviceName = ""

    var canSave: Bool {
        !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        deviceName != device.name
    }

    var body: some View {
        SyncDialog {
            VStack(spacing: 20) {
                Text(UserText.deviceDetailsTitle)
                    .font(.system(size: 17, weight: .bold))

                HStack {
                    Text("Name")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("Device name", text: $deviceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14.5)
                .roundedBorder()
            }
        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }

            Button(UserText.ok) {
                model.delegate?.updateDeviceName(deviceName)
                model.endFlow()
            }
            .disabled(!canSave)
            .buttonStyle(DefaultActionButtonStyle(enabled: canSave))

        }
        .frame(width: 360, height: 178)
        .onAppear {
            deviceName = device.name
        }
    }
}
