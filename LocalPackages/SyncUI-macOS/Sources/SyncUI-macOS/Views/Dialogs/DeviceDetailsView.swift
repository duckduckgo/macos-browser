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
    @State private var isLoading = false

    var canSave: Bool {
        !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        deviceName != device.name
    }

    func submit() {
        guard canSave else { return }
        model.delegate?.updateDeviceName(deviceName)
    }

    var body: some View {
        if isLoading {
            ProgressView()
                .padding()
        } else {
            SyncDialog {
                VStack(spacing: 20) {
                    SyncUIViews.TextHeader(text: UserText.deviceDetailsTitle)
                    HStack {
                        Text(UserText.deviceDetailsLabel)
                            .font(.system(size: 13, weight: .semibold))
                        TextField(UserText.deviceDetailsPrompt, text: $deviceName, onCommit: submit)
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
                .buttonStyle(DismissActionButtonStyle())
                Button(UserText.ok) {
                    submit()
                    isLoading = true
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
}
