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
                        ProgressView()
                    } else {
                        VStack(spacing: 24) {
                            SyncSetupSyncAnotherDeviceCardView()
                            SyncSetupStartSyncView()
                        }
                    }
                }.frame(minWidth: 100)
            }
        }
    }

    struct SyncSetupSyncAnotherDeviceCardView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SyncCard.addDevice.title)
                            .fontWeight(.semibold)
                        Text(SyncCard.addDevice.description)
                            .foregroundColor(.black.opacity(0.6))
                    }
                    QRCodeView(recoveryCode: model.codeToDisplay ?? "")
                    VStack(alignment: .leading, spacing: 8) {
                        if let extraContext = SyncCard.addDevice.extraContext {
                            Text(extraContext)
                                .foregroundColor(.black.opacity(0.6))
                        }
                        Text(SyncCard.addDevice.actionTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("LinkBlueColor"))
                        if let secondActionTitle = SyncCard.addDevice.actionTitle2 {
                            Text(secondActionTitle)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("LinkBlueColor"))
                        }
                    }
                }
                .frame(width: 424)
                Image(SyncCard.addDevice.iconName)
            }
            .padding(32)
            .background(Color.black.opacity(0.01))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
            )
        }
    }

    struct SyncSetupStartSyncView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SyncCard.beginSync.title)
                        .fontWeight(.semibold)
                    Text(SyncCard.beginSync.description)
                        .foregroundColor(.black.opacity(0.6))
                    Button(SyncCard.beginSync.actionTitle) {
                        model.turnOnSync()
                    }
                    .padding(.top, 8)
                }
                .frame(width: 424)
                Image(SyncCard.addDevice.iconName)
            }
            .padding(32)
            .background(Color.black.opacity(0.01))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("HomeFavoritesGhostColor"), style: StrokeStyle(lineWidth: 1.0))
            )
        }
    }
}

struct SyncSetUpCardDescription: View {
    let title: String
    let description: String
    let iconName: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .foregroundColor(.black.opacity(0.6))
            }
            Image(iconName)
        }
    }
}

struct SyncSetupCardView<Content: View>: View {
    let title: String
    let description: String
    let actionTitle: String
    let iconName: String
    let action: () -> Void
    let customContentView: (() -> Content)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
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
            Image(iconName)
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
                return "Sync with Another Device"
            }
        }

        var description: String {
            switch self {
            case .beginSync:
                return "Initiate a new sync, capturing your current bookmarks and logins. This will not merge with previous backups."
            case .addDevice:
                return "To sync with another device, open the DuckDuckGo app on that device. Navigate to Settings > Sync & Back Up and scan the QR code below."
            }
        }

        var actionTitle: String {
            switch self {
            case .beginSync:
                return "Start Sync & Back Up"
            case .addDevice:
                return "Show Text Code"
            }
        }

        var actionTitle2: String? {
            switch self {
            case .beginSync:
                return nil
            case .addDevice:
                return "Manually Enter Code"
            }
        }

        var extraContext: String? {
            switch self {
            case .beginSync:
                return nil
            case .addDevice:
                return "Can't scan the QR code? Copy and paste the text code instead."
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
