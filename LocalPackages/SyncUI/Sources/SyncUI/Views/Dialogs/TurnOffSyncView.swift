//
//  TurnOffSyncView.swift
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

public struct TurnOffSyncView<ViewModel>: View where ViewModel: ManagementViewModel {

    @EnvironmentObject var model: ViewModel

    public init() {}

    public var body: some View {
        SyncDialog {
            VStack(spacing: 20.0) {
                Image("SyncRemoveDeviceDesktop")
                Text(UserText.turnOffSyncConfirmTitle)
                    .font(.system(size: 17, weight: .bold))
                Text(UserText.turnOffSyncConfirmMessage)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .multilineTextAlignment(.center)
            }
        } buttons: {
            Button(UserText.cancel) {
                model.endDialogFlow()
            }
            .buttonStyle(DismissActionButtonStyle())
            Button(UserText.turnOff) {
                model.turnOffSync()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
    }

}
