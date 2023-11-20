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
            Image("Sync-Pair-96x96")
            VStack(alignment: .center, spacing: 8) {
                Text("Begin Sync")
                    .bold()
                    .font(.system(size: 17))
                Text("Safely synchronize your bookmarks and logins between your devices via DuckDuckGo's secure server.")
                    .foregroundColor(Color("BlackWhite60"))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 16)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("LinkBlueColor"))
                    .frame(width: 220, height: 32)
                Text("Sync with Another Device")
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
            syncWithAnotherDeviceView()
            VStack(alignment: .leading, spacing: 12) {
                Text("Other Options")
                    .font(
                        .system(size: 17)
                        .weight(.semibold)
                    )
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync with Server to Back Up")
                        .foregroundColor(Color("LinkBlueColor"))
                        .onTapGesture {
                            model.syncWithServerPressed()
                        }
                    Text("Recover Data")
                        .foregroundColor(Color("LinkBlueColor"))
                        .onTapGesture {
                            model.recoverDataPressed()
                        }
                }
            }
        }
    }
}

// MARK: - QRCodeView
struct QRCodeView: View {
    let recoveryCode: String

    var body: some View {
        VStack(alignment: .center) {
            QRCode(string: recoveryCode, size: .init(width: 160, height: 160))
            Text("Scan this QR code with another device")
                .foregroundColor(Color("GreyTextColor"))
        }
        .padding(.vertical, 16)
        .frame(width: 480)
        .background(ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("BlackWhite10"), lineWidth: 1)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("ClearColor"))
        })
    }
}
