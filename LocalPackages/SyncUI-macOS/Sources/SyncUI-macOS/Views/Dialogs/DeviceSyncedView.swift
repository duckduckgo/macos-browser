//
//  DeviceSyncedView.swift
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

struct DeviceSyncedView: View {
    @EnvironmentObject var model: ManagementDialogModel
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        SyncDialog(spacing: 20.0) {
            VStack(alignment: .center, spacing: 20) {
                Image(.syncSetupSuccess)
                SyncUIViews.TextHeader(text: UserText.deviceSynced)
            }
            .frame(width: 320)
        } buttons: {
            Button(UserText.done) {
                model.endFlow()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 360)
        .onReceive(timer, perform: { _ in
            model.endFlow()
        })
    }

}
