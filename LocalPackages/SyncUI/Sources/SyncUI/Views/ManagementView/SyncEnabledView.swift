//
//  SyncEnabledView.swift
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

struct SyncEnabledView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel

    var body: some View {
        PreferencePaneSection {
            SyncStatusView<ViewModel>()
                .environmentObject(model)
        }

        PreferencePaneSection {
            Text(UserText.syncedDevices)
                .font(Const.Fonts.preferencePaneSectionHeader)

            SyncedDevicesView<ViewModel>()
                .environmentObject(model)
        }

        PreferencePaneSection {
            Text(UserText.syncNewDevice)
                .font(Const.Fonts.preferencePaneSectionHeader)

            SyncNewDeviceView<ViewModel>()
                .environmentObject(model)
        }

        PreferencePaneSection {
            Text(UserText.recovery)
                .font(Const.Fonts.preferencePaneSectionHeader)

            HStack(alignment: .top, spacing: 12) {
                Text(UserText.recoveryInstructions)
                    .fixMultilineScrollableText()
                Spacer()
                Button(UserText.saveRecoveryPDF) {
                    print("save recovery PDF")
                }
            }
        }

        PreferencePaneSection {
            Button(UserText.turnOffAndDeleteServerData) {
                print("turn off and delete server data")
            }
        }
    }
}
