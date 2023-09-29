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
        if isFirstDevice {
            return 450
        }
        if shouldShowOptions {
            return 500
        }
        return min(450, 290 + (CGFloat(devices.count) * 44))
    }
    var title: String {
        if isFirstDevice {
            return UserText.allSetDialogTitle
        }
        return UserText.deviceSynced
    }

    var body: some View {
        SyncDialog(spacing: 20.0) {
            VStack(spacing: 20) {
                Image("Sync-setup-success")
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                if isFirstDevice {
                    NewDeviceDescriptionView()
                } else {
                    Text(UserText.deviceSyncedExplanation)
                        .multilineTextAlignment(.center)
                }

                if !isFirstDevice {
                    ScrollView {
                        SyncedDevicesList(devices: devices)
                    }
                }
                if shouldShowOptions {
                    OptionsView()
                }
            }
            .frame(width: 320)
            .padding(20)
        } buttons: {
            Button(UserText.next) {
                if isFirstDevice {
                    model.delegate?.presentSaveRecoveryPDF()
                } else {
                    model.endFlow()
                }
            }
        }
        .frame(width: 360,
               height: height)
    }

    struct NewDeviceDescriptionView: View {
        var body: some View {
            Text(UserText.allSetDialogCaption1)
            +
            Text(UserText.allSetDialogCaption2)
                .fontWeight(.bold)
            +
            Text(UserText.allSetDialogCaption3)
            +
            Text(UserText.allSetDialogCaption4)
                .fontWeight(.bold)
        }
    }

    struct OptionsView: View {
        @EnvironmentObject var model: ManagementDialogModel
        var body: some View {
            VStack(spacing: 8) {
                Text(UserText.optionsSectionDialogTitle)
                VStack {
                    Toggle(isOn: $model.isUnifiedFavoritesEnabled) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(UserText.shareFavoritesOptionTitle)
                                .font(Const.Fonts.preferencePaneOptionTitle)
                            Text(UserText.shareFavoritesOptionCaption)
                                .font(Const.Fonts.preferencePaneCaption)
                                .foregroundColor(Color("BlackWhite60"))
                        }
                        .frame(width: 254)
                    }
                    .frame(height: 65)
                    .toggleStyle(.switch)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .roundedBorder()
                }
                .frame(width: 320)
            }
        }
    }
}
