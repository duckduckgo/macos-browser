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

                if model.isEnabled {
                    SyncEnabledView()
                        .environmentObject(model)
                } else {
                    SyncSetupView()
                        .environmentObject(model)
                }
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
                    Button(UserText.turnOnSync) {
                        model.isEnabled = true
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
            Section {
                Text(UserText.syncedDevices)
                    .font(Const.Fonts.preferencePaneSectionHeader)

                SyncedDevicesView()
                    .environmentObject(model)
            }
        }
    }
}

private struct SyncStatusView: View {
    @EnvironmentObject var model: SyncPreferences

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .tertiaryLabelColor), lineWidth: 1)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternaryLabelColor))

            HStack(spacing: 12) {
                Image("SolidCheckmark")
                Text(UserText.syncConnected)
                Spacer()
                Button(UserText.turnOffSync) {
                    model.isEnabled = false
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 40)
        }
    }
}

private struct SyncedDevicesView: View {
    @EnvironmentObject var model: SyncPreferences

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .tertiaryLabelColor), lineWidth: 1)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .quaternaryLabelColor))

            VStack(spacing: 0) {
                ForEach(model.syncedDevices) { device in
                    if !device.isCurrent {
                        Rectangle()
                            .fill(Color(nsColor: .quaternaryLabelColor))
                            .frame(height: 1)
                            .padding(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
                    }
                    ZStack {
                        HStack(spacing: 12) {
                            SyncedDeviceIcon(kind: device.kind)
                            Text(device.name)

                            Spacer()

                            if device.isCurrent {
                                Button(UserText.currentDeviceDetails) {
                                    print("details")
                                }
                            }
                        }
                        .padding(10)
                    }
                }
            }

        }
    }
}

private struct SyncedDeviceIcon: View {
    var kind: SyncedDevice.Kind

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
                .fill(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 24, height: 24)

            Image(nsImage: image)
                .aspectRatio(contentMode: .fit)
        }
    }
}
