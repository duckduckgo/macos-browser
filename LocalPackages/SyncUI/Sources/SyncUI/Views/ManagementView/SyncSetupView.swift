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

    var body: some View {
        Text(UserText.syncSetupExplanation)
            .fixMultilineScrollableText()
            .padding(.horizontal, 16)
        PreferencePaneSection {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if model.isCreatingAccount {
                        ProgressView()
                    } else {
                        VStack(spacing: 24) {
                            SyncSetupSyncAnotherDeviceCardView()
                            SyncSetupStartCardView()
                            SyncSetupRecoverCardView()
                            Text(UserText.syncAddDeviceCardExplanation)
                                .font(.system(size: 11))
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.horizontal, 16)
                        }
                    }
                }.frame(minWidth: 100)
            }
        }
    }

}

// MARK: - Card Views
extension SyncSetupView {
    struct SyncSetupSyncAnotherDeviceCardView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(UserText.syncAddDeviceCardExplanation)
                        .foregroundColor(.black.opacity(0.6))
                    QRCodeView(recoveryCode: model.codeToDisplay ?? "")
                    VStack(alignment: .leading, spacing: 8) {
                        Text(UserText.syncAddDeviceCardActionsExplanation)
                            .foregroundColor(.black.opacity(0.6))
                        Text(UserText.syncAddDeviceShowTextActionTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("LinkBlueColor"))
                        Text(UserText.syncAddDeviceEnterCodeActionTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("LinkBlueColor"))
                    }
                }
                .frame(width: 424, alignment: .topLeading)
                Image("Sync-Pair-96x96")
            }
            .padding(16)
            .background(Color.black.opacity(0.01))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
            )
        }
    }

    struct SyncSetupStartCardView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(UserText.syncFirstDeviceSetUpCardTitle)
                        .fontWeight(.semibold)
                    Text(UserText.syncFirstDeviceSetUpCardExplanation)
                        .foregroundColor(.black.opacity(0.6))
                    Button(UserText.syncFirstDeviceSetUpActionTitle) {
                        model.turnOnSync()
                    }
                }
                .frame(width: 424, alignment: .topLeading)
                Image("Sync-Desktop-New-96x96")
            }
            .padding(16)
            .background(Color.black.opacity(0.01))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
            )
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
            .background(Color.black.opacity(0.01))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
            )
        }
    }
}

// MARK: - QRCodeView
extension SyncSetupView {
    struct QRCodeView: View {
        let recoveryCode: String

        var body: some View {
            VStack(alignment: .center) {
                QRCode(string: recoveryCode, size: .init(width: 256, height: 256))
                Text("Scan this QR code with another device")
                    .foregroundColor(Color("GreyTextColor"))
            }
            .padding(.vertical, 16)
            .frame(width: 480)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
            )
        }
    }
}

//        PreferencePaneSection {
//            HStack(alignment: .top, spacing: 12) {
//                Text(UserText.syncSetupExplanation)
//                    .fixMultilineScrollableText()
//                Spacer()
//                Group {
//                    if model.isCreatingAccount {
//                        ProgressView()
//                    } else {
//                        Button(UserText.turnOnSyncWithEllipsis) {
//                            model.presentEnableSyncDialog()
//                        }
//                    }
//                }.frame(minWidth: 100)
//            }
//        }
//
//        PreferencePaneSection {
//            HStack {
//                Spacer()
//                Image("SyncSetup")
//                Spacer()
//            }
//        }
//
//        PreferencePaneSection {
//            TextButton(UserText.recoverSyncedData) {
//                model.presentRecoverSyncAccountDialog()
//            }
//        }
