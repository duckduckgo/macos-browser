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
import PreferencesUI_macOS

struct SyncEnabledView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel

    var body: some View {
        // Errors
        VStack(alignment: .leading, spacing: 16) {
            syncUnavailableView()
            if model.isSyncPaused {
                syncPaused()
            }
            if model.isSyncBookmarksPaused {
                syncPaused(for: .bookmarks)
            }
            if model.isSyncCredentialsPaused {
                syncPaused(for: .credentials)
            }
            if !model.invalidBookmarksTitles.isEmpty {
                syncHasInvalidItems(for: .bookmarks)
            }
            if !model.invalidCredentialsTitles.isEmpty {
                syncHasInvalidItems(for: .credentials)
            }
        }

        // Sync Enabled
        PreferencePaneSection {
            SyncStatusView<ViewModel>()
                .environmentObject(model)
        }

        // Synced Devices
        PreferencePaneSection(UserText.syncedDevices) {
            SyncedDevicesView<ViewModel>()
                .environmentObject(model)
        }

        // Options
        PreferencePaneSection(UserText.optionsSectionTitle) {
            PreferencePaneSubSection {
                ToggleMenuItem(UserText.fetchFaviconsOptionTitle, isOn: $model.isFaviconsFetchingEnabled)
                TextMenuItemCaption(UserText.fetchFaviconsOptionCaption)
            }

            PreferencePaneSubSection {
                ToggleMenuItem(UserText.shareFavoritesOptionTitle, isOn: $model.isUnifiedFavoritesEnabled)
                TextMenuItemCaption(UserText.shareFavoritesOptionCaption)
            }
        }

        // Recovery
        PreferencePaneSection(UserText.recovery) {
            HStack(alignment: .top, spacing: 12) {
                Text(UserText.recoveryInstructions)
                    .fixMultilineScrollableText()
                Spacer()
                Button(UserText.saveRecoveryPDF) {
                    model.saveRecoveryPDF()
                }
            }
        }

        // Turn Off and Delete Data
        PreferencePaneSection {
            Button(UserText.turnOffAndDeleteServerData) {
                model.presentDeleteAccount()
            }
        }
    }

    @ViewBuilder
    func syncPaused() -> some View {
        if let title = model.syncPausedTitle,
           let message = model.syncPausedMessage,
           let buttonTitle = model.syncPausedButtonTitle  {
            if let action = model.syncPausedButtonAction {
                SyncWarningMessage(title: title, message: message, buttonTitle: buttonTitle) {
                    action()
                }
            } else {
                SyncWarningMessage(title: title, message: message, buttonTitle: buttonTitle)
            }
        }

    }

    @ViewBuilder
    func syncPaused(for itemType: LimitedItemType) -> some View {
        var title: String? {
            switch itemType {
            case .bookmarks:
                return model.syncBookmarksPausedTitle
            case .credentials:
                return model.syncCredentialsPausedTitle
            }
        }
        var message: String? {
            switch itemType {
            case .bookmarks:
                return model.syncBookmarksPausedMessage
            case .credentials:
                return model.syncCredentialsPausedMessage
            }
        }
        var buttonTitle: String? {
            switch itemType {
            case .bookmarks:
                return model.syncBookmarksPausedButtonTitle
            case .credentials:
                return model.syncCredentialsPausedButtonTitle
            }
        }

        if let title,
           let message,
           let buttonTitle {
            if let action = model.syncPausedButtonAction {
                SyncWarningMessage(title: title, message: message, buttonTitle: buttonTitle) {
                    action()
                }
            } else {
                SyncWarningMessage(title: title, message: message, buttonTitle: buttonTitle)
            }
        }
    }

    @ViewBuilder
    func syncHasInvalidItems(for itemType: LimitedItemType) -> some View {
        var title: String {
            switch itemType {
            case .bookmarks:
                return UserText.invalidBookmarksPresentTitle
            case .credentials:
                return UserText.invalidCredentialsPresentTitle
            }
        }
        var description: String {
            switch itemType {
            case .bookmarks:
                assert(!model.invalidBookmarksTitles.isEmpty)
                let firstInvalidBookmarkTitle = model.invalidBookmarksTitles.first ?? ""
                return UserText.invalidBookmarksPresentDescription(firstInvalidBookmarkTitle, numberOfInvalidItems: model.invalidBookmarksTitles.count)

            case .credentials:
                assert(!model.invalidCredentialsTitles.isEmpty)
                let firstInvalidCredentialTitle = model.invalidCredentialsTitles.first ?? ""
                return UserText.invalidCredentialsPresentDescription(firstInvalidCredentialTitle, numberOfInvalidItems: model.invalidCredentialsTitles.count)
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
        SyncWarningMessage(title: title, message: description, buttonTitle: actionTitle) {
            switch itemType {
            case .bookmarks:
                model.manageBookmarks()
            case .credentials:
                model.manageLogins()
            }
        }
    }

    @ViewBuilder
    fileprivate func syncUnavailableView() -> some View {
        if model.isDataSyncingAvailable {
            EmptyView()
        } else {
            if model.isAppVersionNotSupported {
                SyncWarningMessage(title: UserText.syncPausedTitle, message: UserText.syncUnavailableMessageUpgradeRequired)
            } else {
                SyncWarningMessage(title: UserText.syncPausedTitle, message: UserText.syncUnavailableMessage)
            }
        }
    }

    enum LimitedItemType {
        case bookmarks
        case credentials
    }
}
