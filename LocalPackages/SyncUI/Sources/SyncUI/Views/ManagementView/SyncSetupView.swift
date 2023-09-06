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
        PreferencePaneSection {
            VStack(alignment: .leading, spacing: 12) {
                Text(UserText.syncSetupExplanation)
                    .fixMultilineScrollableText()
                Spacer()
                Group {
                    if model.isCreatingAccount {
                        if #available(macOS 11.0, *) {
                            ProgressView()
                        } else {
                            EmptyView()
                        }
                    } else {
                        VStack(spacing: 24) {
                            SyncSetupCardView(
                                title: SyncCard.addDevice.title,
                                description: SyncCard.addDevice.description,
                                actionTitle: SyncCard.addDevice.actionTitle,
                                iconName: SyncCard.addDevice.iconName,
                                action: model.presentSyncAnotherDeviceDialog) {
                                    QRCodeView(recoveryCode: model.codeToDisplay ?? "")
                                }
                            SyncSetupCardView(
                                title: SyncCard.beginSync.title,
                                description: SyncCard.beginSync.description,
                                actionTitle: SyncCard.beginSync.actionTitle,
                                iconName: SyncCard.beginSync.iconName,
                                action: model.turnOnSync) {
                                    EmptyView()
                                }
                        }
                    }
                }.frame(minWidth: 100)
            }
        }
    }
}

struct SyncSetupCardView<Content:View>: View {
    let title: String
    let description: String
    let actionTitle: String
    let iconName: String
    let action: () -> Void
    let customContentView: (() -> Content)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(iconName)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.semibold)
                    Text(description)
                        .foregroundColor(Color("GreyTextColor"))
                }
                customContentView()
                Button(actionTitle) {
                    action()
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(width: 512)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
        )
    }
}

extension SyncSetupView {
    enum SyncCard {
        case beginSync
        case addDevice

        var title: String {
            switch self {
            case .beginSync:
                return "Begin New Sync"
            case .addDevice:
                return "Reconnect to Previous Sync"
            }
        }

        var description: String {
            switch self {
            case .beginSync:
                return "Initiate a new sync, capturing your current bookmarks and logins. This will not merge with previous backups."
            case .addDevice:
                return "Retrieve your saved bookmarks and logins from an earlier synchronization. You'll need a device that was synced earlier or your Backup Code."
            }
        }

        var actionTitle: String {
            switch self {
            case .beginSync:
                return "Start Fresh"
            case .addDevice:
                return "Reconnect Now"
            }
        }

        var iconName: String {
            switch self {
            case .beginSync:
                return "Sync-Desktop-New-96"
            case .addDevice:
                return "SyncTurnOnDialog"
            }
        }

    }
}

struct QRCodeView: View {
    let recoveryCode: String

    var body: some View {
        VStack {
            Text("Scan this QR code with another device")
                .foregroundColor(Color("GreyTextColor"))
                .frame(alignment: .center)
            QRCode(string: recoveryCode, size: .init(width: 256, height: 256))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
        )
    }
}
