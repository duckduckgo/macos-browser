//
//  SyncEnabledView.swift
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

struct SyncEnabledView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel

    var body: some View {
        if model.isSyncBookmarksPaused {
            syncPaused(for: .bookmarks)
        }
        if model.isSyncCredentialsPaused {
            syncPaused(for: .credentials)
        }

        PreferencePaneSection(vericalPadding: 12) {
            SyncStatusView<ViewModel>()
                .environmentObject(model)
                .frame(width: 513, alignment: .topLeading)
        }

        PreferencePaneSection(vericalPadding: 12) {
            Text(UserText.syncedDevices)
                .font(Const.Fonts.preferencePaneSectionHeader)
                .padding(.horizontal, 16)
            SyncedDevicesView<ViewModel>()
                .environmentObject(model)
                .frame(width: 513, alignment: .topLeading)
        }

        PreferencePaneSection(vericalPadding: 12) {
            Text(UserText.syncNewDevice)
                .font(Const.Fonts.preferencePaneSectionHeader)
                .padding(.horizontal, 16)
            SyncSetupSyncAnotherDeviceCardView<ViewModel>(code: model.recoveryCode ?? "")
                .environmentObject(model)
        }

        PreferencePaneSection(vericalPadding: 12) {
            Text(UserText.optionsSectionTitle)
                .font(Const.Fonts.preferencePaneSectionHeader)
                .padding(.horizontal, 16)
            Toggle(isOn: $model.isUnifiedFavoritesEnabled) {
                HStack {
                    IconOnBackground(image: NSImage(imageLiteralResourceName: "SyncAllDevices"))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(UserText.shareFavoritesOptionTitle)
                            .font(Const.Fonts.preferencePaneOptionTitle)
                        Text(UserText.shareFavoritesOptionCaption)
                            .font(Const.Fonts.preferencePaneCaption)
                            .foregroundColor(Color("BlackWhite60"))
                    }
                    Spacer(minLength: 30)
                }
            }
            .padding(.horizontal, 16)
            .toggleStyle(.switch)
            .padding(.vertical, 12)
            .roundedBorder()
            .frame(width: 513, alignment: .topLeading)
        }

        PreferencePaneSection(vericalPadding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(UserText.recovery)
                    .font(Const.Fonts.preferencePaneSectionHeader)
                HStack(alignment: .top, spacing: 12) {
                    Text(UserText.recoveryInstructions)
                        .fixMultilineScrollableText()
                    Spacer()
                    Button(UserText.saveRecoveryPDF) {
                        model.saveRecoveryPDF()
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(width: 513, alignment: .topLeading)
        }

        PreferencePaneSection(vericalPadding: 12) {
            Button(UserText.turnOffAndDeleteServerData) {
                model.presentDeleteAccount()
            }
            .padding(16)
        }
    }

    @ViewBuilder
    func syncPaused(for itemType: LimitedItemType) -> some View {
        var description: String {
            switch itemType {
            case .bookmarks:
                return UserText.bookmarksLimitExceededDescription
            case .credentials:
                return UserText.credentialsLimitExceededDescription
            }
        }
        var actionTitle: String {
            switch itemType {
            case .bookmarks:
                return UserText.bookmarksLimitExceededAction
            case .credentials:
                return UserText.credentialsLimitExceededAction
            }
        }
        PreferencePaneSection(vericalPadding: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text("⚠️")
                VStack(alignment: .leading, spacing: 8) {
                    Text(UserText.syncLimitExceededTitle)
                        .bold()
                    Text(description)
                    Button(actionTitle) {
                        switch itemType {
                        case .bookmarks:
                            model.manageBookmarks()
                        case .credentials:
                            model.manageLogins()
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(RoundedRectangle(cornerRadius: 8).foregroundColor(Color("AlertBubbleBackground")))
    }

    enum LimitedItemType {
        case bookmarks
        case credentials
    }
}
