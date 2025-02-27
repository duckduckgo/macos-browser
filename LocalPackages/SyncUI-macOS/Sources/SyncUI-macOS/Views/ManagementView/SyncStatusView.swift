//
//  SyncStatusView.swift
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

struct SyncStatusView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SyncPreferencesRow {
                Image(.solidCheckmark)
            } centerContent: {
                Text(UserText.syncConnected)
                    .foregroundColor(Color(.blackWhite60))
            } rightContent: {
                Button(UserText.turnOffSync) {
                    model.turnOffSyncPressed()
                }
            }
            .roundedBorder()
        }
    }
}
