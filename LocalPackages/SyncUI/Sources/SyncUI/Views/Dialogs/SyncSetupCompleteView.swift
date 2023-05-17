//
//  SyncSetupCompleteView.swift
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

struct SyncSetupCompleteView: View {
    @EnvironmentObject var model: ManagementDialogModel

    let devices: [SyncDevice]

    var body: some View {
        SyncDialog(spacing: 20.0) {
            VStack(spacing: 20) {
                Image("SyncSetupComplete")
                Text(UserText.deviceSynced)
                    .font(.system(size: 17, weight: .bold))
                Text(UserText.deviceSyncedExplanation)
                    .multilineTextAlignment(.center)

                ScrollView {
                    SyncedDevicesList(devices: devices)
                }

            }
        } buttons: {
            Button(UserText.next) {
                model.delegate?.confirmSetupComplete()
            }
        }
        .frame(width: 360,
               // Grow with the number of devices, up to a point
               height: min(410, 258 + (CGFloat(devices.count) * 44)))

    }
}
