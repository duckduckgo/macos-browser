//
//  SyncWithServerView.swift
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

struct SyncWithServerView: View {
    @EnvironmentObject var model: ManagementDialogModel

    var body: some View {
        SyncDialog(spacing: 20.0) {
            Image("Sync-Server-96")
            SyncUIConstants.TextHeader(text: "Sync and Back Up This Device")
            SyncUIConstants.TextDetailMultiline(text: "Your bookmarks and saved logins will be encrypted and begin syncing with DuckDuckGo's server.")
            SyncUIConstants.TextDetailMultiline(text: "Only your device holds the decryption key; DuckDuckGo cannot access it.")
            Spacer()
            Text("You can add other devices for syncing later.")
                .font(.system(size: 11))
                .foregroundColor(Color("BlackWhite60"))
        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }
            .buttonStyle(DismissActionButtonStyle())
            Button("Turn on Sync") {
                model.delegate?.turnOnSync()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
    }
}
