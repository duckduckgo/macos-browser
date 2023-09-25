//
//  SetUpAllSetView.swift
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

struct SetUpAllSetView: View {
    @EnvironmentObject var model: ManagementDialogModel

    var body: some View {
        SyncDialog {
            VStack(spacing: 20.0) {
                Image("Sync-setup-success")
                Text(UserText.allSetDialogTitle)
                    .font(.system(size: 17, weight: .bold))
                Text(UserText.allSetDialogCaption1)
                +
                Text(UserText.allSetDialogCaption2)
                    .fontWeight(.bold)
                +
                Text(UserText.allSetDialogCaption3)
                +
                Text(UserText.allSetDialogCaption4)
                    .fontWeight(.bold)
            }
        } buttons: {
            Button(UserText.next) {
                model.delegate?.presentSaveRecoveryPDF()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(height: 266)
    }
}
