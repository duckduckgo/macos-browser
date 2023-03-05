//
//  SyncManagementView.swift
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

enum Const {
    enum Fonts {
        static let preferencePaneTitle: Font = {
            if #available(macOS 11.0, *) {
                return .title2.weight(.semibold)
            } else {
                return .system(size: 17, weight: .semibold)
            }
        }()

        static let preferencePaneSectionHeader: Font = {
            if #available(macOS 11.0, *) {
                return .title3.weight(.semibold)
            } else {
                return .system(size: 15, weight: .semibold)
            }
        }()

        static let preferencePaneCaption: Font = {
            if #available(macOS 11.0, *) {
                return .subheadline
            } else {
                return .system(size: 10)
            }
        }()
    }
}

public protocol SyncManagementViewModel: ObservableObject {
    associatedtype SyncManagementViewUserText: SyncUI.SyncManagementViewUserText

    var isSyncEnabled: Bool { get }
    var shouldShowErrorMessage: Bool { get set }
    var errorMessage: String? { get }

    var recoveryCode: String? { get }
    var devices: [SyncDevice] { get }

    func presentEnableSyncDialog()
    func presentRecoverSyncAccountDialog()
    func turnOffSync()
}

public protocol SyncManagementViewUserText {
    static var sync: String { get }
    static var ok: String { get }
    static var syncSetupExplanation: String { get }
    static var turnOnSyncWithEllipsis: String { get }
    static var recoverSyncedData: String { get }
    static var syncedDevices: String { get }
    static var syncNewDevice: String { get }
    static var recovery: String { get }
    static var recoveryInstructions: String { get }
    static var saveRecoveryPDF: String { get }
    static var turnOffAndDeleteServerData: String { get }
    static var syncNewDeviceInstructions: String { get }
    static var showOrEnterCode: String { get }
    static var syncConnected: String { get }
    static var turnOffSync: String { get }
    static var thisDevice: String { get }
    static var currentDeviceDetails: String { get }
}

public struct SyncManagementView<ViewModel>: View where ViewModel: SyncManagementViewModel {
    typealias UserText = ViewModel.SyncManagementViewUserText

    @ObservedObject public var model: ViewModel

    public init(model: ViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(UserText.sync)
                .font(Const.Fonts.preferencePaneTitle)

            if model.isSyncEnabled {
                SyncEnabledView<ViewModel>()
                    .environmentObject(model)
            } else {
                SyncSetupView<ViewModel>()
                    .environmentObject(model)
            }
        }
        .alert(isPresented: $model.shouldShowErrorMessage) {
            Alert(title: Text("Unable to turn on Sync"), message: Text(model.errorMessage ?? "An error occurred"), dismissButton: .default(Text(UserText.ok)))
        }
    }
}

struct SyncSetupView<ViewModel>: View where ViewModel: SyncManagementViewModel {
    typealias UserText = ViewModel.SyncManagementViewUserText
    @EnvironmentObject var model: ViewModel

    var body: some View {
        PreferencePaneSection {
            HStack(alignment: .top, spacing: 12) {
                Text(UserText.syncSetupExplanation)
                    .fixMultilineScrollableText()
                Spacer()
                Button(UserText.turnOnSyncWithEllipsis) {
                    model.presentEnableSyncDialog()
                }
            }
        }

        PreferencePaneSection {
            HStack {
                Spacer()
                Image("SyncSetup")
                Spacer()
            }
        }

        PreferencePaneSection {
            TextButton(UserText.recoverSyncedData) {
                model.presentRecoverSyncAccountDialog()
            }
        }
    }
}

struct SyncEnabledView<ViewModel>: View where ViewModel: SyncManagementViewModel {
    typealias UserText = ViewModel.SyncManagementViewUserText
    @EnvironmentObject var model: ViewModel

    var body: some View {
        PreferencePaneSection {
            SyncStatusView<ViewModel>()
                .environmentObject(model)
        }

        PreferencePaneSection {
            Text(UserText.syncedDevices)
                .font(Const.Fonts.preferencePaneSectionHeader)

            SyncedDevicesView<ViewModel>()
                .environmentObject(model)
        }

        PreferencePaneSection {
            Text(UserText.syncNewDevice)
                .font(Const.Fonts.preferencePaneSectionHeader)

            SyncNewDeviceView<ViewModel>()
                .environmentObject(model)
        }

        PreferencePaneSection {
            Text(UserText.recovery)
                .font(Const.Fonts.preferencePaneSectionHeader)

            HStack(alignment: .top, spacing: 12) {
                Text(UserText.recoveryInstructions)
                    .fixMultilineScrollableText()
                Spacer()
                Button(UserText.saveRecoveryPDF) {
                    print("save recovery PDF")
                }
            }
        }

        PreferencePaneSection {
            Button(UserText.turnOffAndDeleteServerData) {
                print("turn off and delete server data")
            }
        }
    }
}

struct SyncNewDeviceView<ViewModel>: View where ViewModel: SyncManagementViewModel {
    typealias UserText = ViewModel.SyncManagementViewUserText
    @EnvironmentObject var model: ViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            QRCode(string: model.recoveryCode ?? "", size: .init(width: 192, height: 192))

            VStack {
                Text(UserText.syncNewDeviceInstructions)
                    .fixMultilineScrollableText()

                Spacer()

                HStack {
                    Spacer()
                    TextButton(UserText.showOrEnterCode) {
                        print("show or enter code")
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .roundedBorder()
    }
}

private struct SyncStatusView<ViewModel>: View where ViewModel: SyncManagementViewModel {
    typealias UserText = ViewModel.SyncManagementViewUserText
    @EnvironmentObject var model: ViewModel

    var body: some View {
        SyncPreferencesRow {
            Image("SolidCheckmark")
        } centerContent: {
            Text(UserText.syncConnected)
        } rightContent: {
            Button(UserText.turnOffSync) {
                model.turnOffSync()
            }
        }
        .roundedBorder()
    }
}

private struct SyncedDevicesView<ViewModel>: View where ViewModel: SyncManagementViewModel {
    typealias UserText = ViewModel.SyncManagementViewUserText
    @EnvironmentObject var model: ViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.devices) { device in
                if !device.isCurrent {
                    Rectangle()
                        .fill(Color("BlackWhite10"))
                        .frame(height: 1)
                        .padding(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
                }

                if device.isCurrent {
                    SyncPreferencesRow {
                        SyncedDeviceIcon(kind: device.kind)
                    } centerContent: {
                        HStack {
                            Text(device.name)
                            Text("(\(UserText.thisDevice))")
                                .foregroundColor(Color(NSColor.secondaryLabelColor))
                            Spacer()
                        }
                    } rightContent: {
                        Button(UserText.currentDeviceDetails) {
                            print("details")
                        }
                    }
                } else {
                    SyncPreferencesRow {
                        SyncedDeviceIcon(kind: device.kind)
                    } centerContent: {
                        Text(device.name)
                    }
                }
            }
        }
        .roundedBorder()
    }
}

struct SyncedDeviceIcon: View {
    var kind: SyncDevice.Kind

    var image: NSImage {
        switch kind {
        case .current, .desktop:
            return NSImage(imageLiteralResourceName: "SyncedDeviceDesktop")
        case .mobile:
            return NSImage(imageLiteralResourceName: "SyncedDeviceMobile")
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color("BlackWhite100").opacity(0.06))
                .frame(width: 24, height: 24)

            Image(nsImage: image)
                .aspectRatio(contentMode: .fit)
        }
    }
}
