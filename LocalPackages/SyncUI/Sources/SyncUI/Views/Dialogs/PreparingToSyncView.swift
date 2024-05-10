//
//  PreparingToSyncView.swift
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

struct PreparingToSyncView: View {

    var body: some View {
        SyncDialog(spacing: 20.0, bottomText: UserText.preparingToSyncDialogAction) {
            VStack(alignment: .center, spacing: 20) {
                Image(.sync96)
                SyncUIViews.TextHeader(text: UserText.preparingToSyncDialogTitle)
                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    .multilineTextAlignment(.center)
                SyncUIViews.TextDetailMultiline(text: UserText.preparingToSyncDialogSubTitle)
            }
            .frame(width: 320)
        } buttons: {
        }
    }

}

struct RecoverSyncedDataView: View {
    @EnvironmentObject var model: ManagementDialogModel

    var body: some View {
        SyncDialog(spacing: 20.0) {
            VStack(alignment: .center, spacing: 20) {
                Image(.syncPair96)
                SyncUIViews.TextHeader(text: UserText.reciverSyncedDataDialogTitle)
                SyncUIViews.TextDetailMultiline(text: UserText.reciverSyncedDataDialogSubitle)
            }
            .frame(width: 320)
        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }
            .buttonStyle(DismissActionButtonStyle())
            Button(UserText.reciverSyncedDataDialogButton) {
                model.delegate?.enterRecoveryCodePressed()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
    }

}
