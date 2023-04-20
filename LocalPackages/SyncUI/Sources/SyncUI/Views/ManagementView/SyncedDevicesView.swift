//
//  SyncedDevicesView.swift
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

struct SyncedDevicesView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel

    var body: some View {
        VStack(spacing: 0) {
            if #available(macOS 11.0, *) {
                if model.devices.isEmpty {
                    ProgressView()
                        .padding()
                }
            }

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
