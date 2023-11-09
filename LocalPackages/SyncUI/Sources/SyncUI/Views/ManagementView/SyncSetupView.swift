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
            HStack {
                Image("DownloadsPreferences")
                Text("DuckDuckGo for Other Platforms")
                    .foregroundColor(Color("LinkBlueColor"))
            }
            .padding(.top, 12)
            .onTapGesture {
                model.downloadDDGPressed()
            }
        }
    }

//    var body: some View {
//        Text(UserText.syncSetupExplanation)
//            .fixMultilineScrollableText()
//            .padding(.horizontal, 16)
//        PreferencePaneSection {
//            VStack(alignment: .leading, spacing: 12) {
//                Group {
//                    if model.isCreatingAccount {
//                        ProgressView()
//                    } else {
//                        VStack(alignment: .leading, spacing: 24) {
//                            SyncSetupSyncAnotherDeviceCardView<ViewModel>(code: model.codeToDisplay ?? "")
//                                .environmentObject(model)
//                                .onAppear {
//                                    model.startPollingForRecoveryKey()
//                                }
//                                .onDisappear {
//                                    model.stopPollingForRecoveryKey()
//                                }
//                            SyncSetupStartCardView()
//                            SyncSetupRecoverCardView()
//                            Text(UserText.syncSetUpFooter)
//                                .font(.system(size: 11))
//                                .foregroundColor(Color("GreyTextColor"))
//                                .padding(.horizontal, 16)
//                        }
//                    }
//                }.frame(minWidth: 100)
//            }
//        }
//    }

}

// MARK: - Card Views
extension SyncSetupView {
    struct SyncSetupStartCardView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UserText.syncFirstDeviceSetUpCardTitle)
                            .fontWeight(.semibold)
                        Text(UserText.syncFirstDeviceSetUpCardExplanation)
                            .foregroundColor(Color("GreyTextColor"))
                    }
                    Button(UserText.syncFirstDeviceSetUpActionTitle) {
                        model.turnOnSync()
                    }
                }
                .frame(width: 424, alignment: .topLeading)
                Image("Sync-Desktop-New-96x96")
            }
            .padding(16)
            .roundedBorder()
        }
    }

    struct SyncSetupRecoverCardView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            HStack {
                Button(UserText.syncRecoverDataActionTitle) {
                    model.presentRecoverSyncAccountDialog()
                }
                Spacer()
            }
            .padding(16)
            .frame(width: 512)
            .roundedBorder()
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

struct SyncSetupSyncAnotherDeviceCardView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel
    let code: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 16) {
                Text(UserText.syncAddDeviceCardExplanation)
                    .foregroundColor(Color("GreyTextColor"))
                QRCodeView(recoveryCode: code)
                VStack(alignment: .leading, spacing: 8) {
                    Text(UserText.syncAddDeviceCardActionsExplanation)
                        .foregroundColor(Color("GreyTextColor"))
                    Text(UserText.syncAddDeviceShowTextActionTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("LinkBlueColor"))
                        .onTapGesture {
                            model.presentShowTextCodeDialog()
                        }
                    Text(UserText.syncAddDeviceEnterCodeActionTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("LinkBlueColor"))
                        .onTapGesture {
                            model.presentManuallyEnterCodeDialog()
                        }
                }
            }
            .frame(width: 424, alignment: .topLeading)
            Image("Sync-Pair-96x96")
        }
        .padding(16)
        .roundedBorder()
    }
}
