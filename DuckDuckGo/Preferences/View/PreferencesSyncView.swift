//
//  PreferencesSyncView.swift
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

extension Preferences {

    struct SyncView: View {
        @ObservedObject var model: SyncPreferences

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.sync)
                    .font(Const.Fonts.preferencePaneTitle)

                if model.isSyncEnabled {
                    SyncEnabledView()
                        .environmentObject(model)
                } else {
                    SyncSetupView()
                        .environmentObject(model)
                }
            }
            .alert(isPresented: $model.shouldShowErrorMessage) {
                Alert(title: Text("Unable to turn on Sync"), message: Text(model.errorMessage ?? "An error occurred"), dismissButton: .default(Text(UserText.ok)))
            }
        }
    }

    struct SyncSetupView: View {
        @EnvironmentObject var model: SyncPreferences

        var body: some View {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Text(UserText.syncSetupExplanation)
                        .fixMultilineScrollableText()
                    Spacer()
                    Button(UserText.turnOnSyncWithEllipsis) {
                        model.presentEnableSyncDialog()
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Image("SyncSetup")
                    Spacer()
                }
            }

            Section {
                TextButton(UserText.recoverSyncedData) {
                    print("recover")
                }
            }
        }
    }

    struct SyncEnabledView: View {
        @EnvironmentObject var model: SyncPreferences

        var body: some View {
            Section {
                SyncStatusView()
                    .environmentObject(model)
            }
//            Section {
//                Text(UserText.syncedDevices)
//                    .font(Const.Fonts.preferencePaneSectionHeader)
//
//                SyncedDevicesView()
//                    .environmentObject(model)
//            }
//
//            Section {
//                Text(UserText.syncNewDevice)
//                    .font(Const.Fonts.preferencePaneSectionHeader)
//
//                SyncNewDeviceView()
//                    .environmentObject(model)
//            }
//
//            Section {
//                Text(UserText.recovery)
//                    .font(Const.Fonts.preferencePaneSectionHeader)
//
//                HStack(alignment: .top, spacing: 12) {
//                    Text(UserText.recoveryInstructions)
//                        .fixMultilineScrollableText()
//                    Spacer()
//                    Button(UserText.saveRecoveryPDF) {
//                        print("save recovery PDF")
//                    }
//                }
//                Button(UserText.turnOffAndDeleteServerData) {
//                    print("turn off and delete server data")
//                }
//            }
        }
    }

//    struct SyncNewDeviceView: View {
//        @EnvironmentObject var model: SyncPreferences
//
//        var body: some View {
//            Outline {
//                HStack(alignment: .top, spacing: 20) {
//                    QRCode(string: model.syncKey, size: .init(width: 192, height: 192))
//
//                    VStack {
//                        Text(UserText.syncNewDeviceInstructions)
//                            .fixMultilineScrollableText()
//
//                        Spacer()
//
//                        HStack {
//                            Spacer()
//                            TextButton(UserText.showOrEnterCode) {
//                                print("show or enter code")
//                            }
//                        }
//                    }
//                    .frame(maxHeight: .infinity)
//                }
//                .padding(20)
//            }
//        }
//    }

}

struct Outline<Content>: View where Content: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("BlackWhite10"), lineWidth: 1)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("BlackWhite1"))

            content()
        }
    }
}

struct SyncPreferencesRow<ImageContent, CenterContent, RightContent>: View where ImageContent: View, CenterContent: View, RightContent: View {
    @ViewBuilder let imageContent: () -> ImageContent
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let rightContent: () -> RightContent

    init(
        imageContent: @escaping () -> ImageContent,
        centerContent: @escaping () -> CenterContent,
        rightContent: @escaping () -> RightContent = { EmptyView() }
    ) {
        self.imageContent = imageContent
        self.centerContent = centerContent
        self.rightContent = rightContent
    }

    var body: some View {
        HStack(spacing: 12) {
            imageContent()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            centerContent()
            Spacer()
            rightContent()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 40)
    }
}

private struct SyncStatusView: View {
    @EnvironmentObject var model: SyncPreferences

    var body: some View {
        Outline {
            SyncPreferencesRow {
                Image("SolidCheckmark")
            } centerContent: {
                Text(UserText.syncConnected)
            } rightContent: {
                Button(UserText.turnOffSync) {
                    model.turnOffSync()
                }
            }
        }
    }
}
//
//private struct SyncedDevicesView: View {
//    @EnvironmentObject var model: SyncPreferences
//
//    var body: some View {
//        Outline {
//
//            VStack(spacing: 0) {
//                ForEach(model.syncedDevices) { device in
//                    if !device.isCurrent {
//                        Rectangle()
//                            .fill(Color("BlackWhite10"))
//                            .frame(height: 1)
//                            .padding(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
//                    }
//
//                    if device.isCurrent {
//                        SyncPreferencesRow {
//                            SyncedDeviceIcon(kind: device.kind)
//                        } centerContent: {
//                            Text(device.name)
//                        } rightContent: {
//                            Button(UserText.currentDeviceDetails) {
//                                print("details")
//                            }
//                        }
//                    } else {
//                        SyncPreferencesRow {
//                            SyncedDeviceIcon(kind: device.kind)
//                        } centerContent: {
//                            Text(device.name)
//                        }
//                    }
//                }
//            }
//        }
//    }
//}
//
//struct SyncedDeviceIcon: View {
//    var kind: SyncedDevice.Kind
//
//    var image: NSImage {
//        switch kind {
//        case .current, .desktop:
//            return NSImage(imageLiteralResourceName: "SyncedDeviceDesktop")
//        case .mobile:
//            return NSImage(imageLiteralResourceName: "SyncedDeviceMobile")
//        }
//    }
//
//    var body: some View {
//        ZStack {
//            RoundedRectangle(cornerRadius: 4)
//                .fill(Color("BlackWhite100").opacity(0.06))
//                .frame(width: 24, height: 24)
//
//            Image(nsImage: image)
//                .aspectRatio(contentMode: .fit)
//        }
//    }
//}
