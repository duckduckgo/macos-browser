//
//  SyncSetupView.swift
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

struct SyncSetupView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel

    fileprivate func syncWithAnotherDeviceView() -> some View {
        return VStack(alignment: .center, spacing: 16) {
            Image("Sync-Pair-96")
            VStack(alignment: .center, spacing: 8) {
                SyncUIViews.TextHeader(text: UserText.beginSyncTitle)
                SyncUIViews.TextDetailSecondary(text: UserText.beginSyncDescription)
            }
            .padding(.bottom, 16)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("LinkBlueColor"))
                    .frame(width: 220, height: 32)
                Text(UserText.beginSyncButton)
                    .foregroundColor(.white)
                    .bold()
            }
            .onTapGesture {
                model.syncWithAnotherDevicePressed()
            }
        }
        .frame(width: 512, height: 254)
        .roundedBorder()
        .padding(.top, 20)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                syncWithAnotherDeviceView()
                SyncUIViews.TextDetailSecondary(text: UserText.beginSyncFooter)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 110)
                    .font(.system(size: 11))
            }
            VStack(alignment: .leading, spacing: 12) {
                SyncUIViews.TextHeader2(text: UserText.otherOptionsSectionTitle)
                VStack(alignment: .leading, spacing: 8) {
                    SyncUIViews.TextLink(text: UserText.syncThisDeviceLink)
                        .onTapGesture {
                            model.syncWithServerPressed()
                        }
                    SyncUIViews.TextLink(text: UserText.recoverDataLink)
                        .onTapGesture {
                            model.recoverDataPressed()
                        }
                }
            }
        }
    }
}
