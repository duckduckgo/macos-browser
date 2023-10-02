//
//  DeviceSyncedView.swift
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

struct DeviceSyncedView: View {
    @EnvironmentObject var model: ManagementDialogModel

    let devices: [SyncDevice]
    let shouldShowOptions: Bool
    let isFirstDevice: Bool
    var height: CGFloat {
        if shouldShowOptions {
            return 400
        } else {
            return 250
        }
    }
    var title: String {
        if isFirstDevice {
            return UserText.allSetDialogTitle
        }
        return UserText.deviceSynced
    }

    var body: some View {
        SyncDialog(spacing: 20.0) {
            VStack(alignment: .center, spacing: 20) {
                Image("Sync-setup-success")
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                VStack(alignment: .center) {
                    if isFirstDevice {
                        SingleDeviceSetTextView()
                    } else {
                        NewDeviceSyncedView(devices: devices)
                    }
                }
                if shouldShowOptions {
                    OptionsView()
                }
            }
            .frame(width: 320)
        } buttons: {
            Button(UserText.next) {
                if isFirstDevice {
                    model.delegate?.presentSaveRecoveryPDF()
                } else {
                    model.endFlow()
                }
            }
        }
        .padding(.vertical, 20)
        .frame(width: 360,
               height: height)
    }

    struct SingleDeviceSetTextView: View {
        var body: some View {
            Text(UserText.allSetDialogCaption)
                .frame(width: 320, alignment: .center)
                .multilineTextAlignment(.center)
                .fixedSize()
        }
    }

    struct NewDeviceSyncedView: View {
        let devices: [SyncDevice]
        var body: some View {
            if devices.count > 1 {
                VStack(alignment: .center) {
                    Text(UserText.multipleDeviceSyncedExplanation)
                    Text("\(devices.count + 1) ")
                        .fontWeight(.bold)
                    +
                    Text(UserText.devicesWord)
                        .fontWeight(.bold)
                }
            } else {
                VStack(alignment: .center) {
                    Text(UserText.deviceSyncedExplanation)
                    Text("\(devices[0].name)")
                        .fontWeight(.bold)
                }
            }
        }
    }

    struct OptionsView: View {
        @EnvironmentObject var model: ManagementDialogModel
        var body: some View {
            VStack(spacing: 8) {
                Text(UserText.optionsSectionDialogTitle)
                    .font(.system(size: 11))
                    .foregroundColor(Color("BlackWhite60"))
                VStack {
                    Toggle(isOn: $model.isUnifiedFavoritesEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(UserText.shareFavoritesOptionTitle)
                                .font(.system(size: 13))
                                .foregroundColor(Color("BlackWhite80"))
                            Text(UserText.shareFavoritesOptionCaption)
                                .font(.system(size: 11))
                                .foregroundColor(Color("BlackWhite60"))
                                .frame(width: 254)
                                .fixedSize()
                        }
                        .frame(width: 254)
                    }
                    .padding(.bottom, 13)
                    .padding(.top, 7)
                    .padding(.horizontal, 16)
                    .frame(height: 65)
                    .toggleStyle(.switch)
                    .roundedBorder()
                }
                .frame(width: 320)
            }
            .padding(.top, 32)
        }
    }
}
