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
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                syncUnavailableView()
                syncWithAnotherDeviceView()
                SyncUIViews.TextDetailSecondary(text: UserText.beginSyncFooter)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 110)
                    .font(.system(size: 11))
            }
            VStack(alignment: .leading, spacing: 12) {
                SyncUIViews.TextHeader2(text: UserText.otherOptionsSectionTitle)
                VStack(alignment: .leading, spacing: 8) {
                    TextButton(UserText.syncThisDeviceLink, weight: .semibold) {
                        Task {
                            await model.syncWithServerPressed()
                        }
                    }
                    .disabled(!model.isAccountCreationAvailable)

                    TextButton(UserText.recoverDataLink, weight: .semibold) {
                        Task {
                            await model.recoverDataPressed()
                        }
                    }
                    .disabled(!model.isAccountRecoveryAvailable)
                }
            }
        }
    }

    fileprivate func syncWithAnotherDeviceView() -> some View {
        VStack(alignment: .center, spacing: 16) {
            Image(.syncPair96)
            VStack(alignment: .center, spacing: 8) {
                SyncUIViews.TextHeader(text: UserText.beginSyncTitle)
                SyncUIViews.TextDetailSecondary(text: UserText.beginSyncDescription)
            }
            .padding(.bottom, 16)
            Button(UserText.beginSyncButton) {
                Task {
                    await model.syncWithAnotherDevicePressed()
                }
            }
            .buttonStyle(SyncWithAnotherDeviceButtonStyle(enabled: model.isConnectingDevicesAvailable))
            .disabled(!model.isConnectingDevicesAvailable)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 254)
        .roundedBorder()
        .padding(.top, 20)
    }

    @ViewBuilder
    fileprivate func syncUnavailableView() -> some View {
        if !model.isDataSyncingAvailable || !model.isConnectingDevicesAvailable || !model.isAccountCreationAvailable {
            if model.isAppVersionNotSupported {
                SyncWarningMessage(title: UserText.syncUnavailableTitle, message: UserText.syncUnavailableMessageUpgradeRequired)
                    .padding(.top, 16)
            } else {
                SyncWarningMessage(title: UserText.syncUnavailableTitle, message: UserText.syncUnavailableMessage)
                    .padding(.top, 16)
            }
        } else {
            EmptyView()
        }
    }
}

private struct SyncWithAnotherDeviceButtonStyle: ButtonStyle {

    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public func makeBody(configuration: Self.Configuration) -> some View {

        let enabledBackgroundColor = configuration.isPressed ? Color(NSColor.controlAccentColor).opacity(0.5) : Color(NSColor.controlAccentColor)
        let disabledBackgroundColor = Color.gray.opacity(0.1)
        let labelColor = enabled ? Color.white : Color.primary.opacity(0.3)

        configuration.label
            .lineLimit(1)
            .font(.body.bold())
            .frame(height: 32)
            .padding(.horizontal, 24)
            .background(enabled ? enabledBackgroundColor : disabledBackgroundColor)
            .foregroundColor(labelColor)
            .cornerRadius(8)
    }
}
