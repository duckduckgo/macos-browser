//
//  UserText.swift
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

import Foundation

enum UserText {

    // Generic Buttons
    static let ok = NSLocalizedString("ok", bundle: Bundle.module, value: "OK", comment: "OK button")
    static let notNow = NSLocalizedString("notnow", bundle: Bundle.module, value: "Not Now", comment: "Not Now button")
    static let cancel = NSLocalizedString("cancel", bundle: Bundle.module, value: "Cancel", comment: "Cancel button")
    static let submit = NSLocalizedString("submit", bundle: Bundle.module, value: "Submit", comment: "Submit button")
    static let next = NSLocalizedString("next", bundle: Bundle.module, value: "Next", comment: "Next button")
    static let copy = NSLocalizedString("copy", bundle: Bundle.module, value: "Copy", comment: "Copy button")
    static let share = NSLocalizedString("share", bundle: Bundle.module, value: "Share", comment: "Share button")
    static let paste = NSLocalizedString("paste", bundle: Bundle.module, value: "Paste", comment: "Paste button")
    static let pasteFromClipboard = NSLocalizedString("paste-from-clipboard", bundle: Bundle.module, value: "Paste from Clipboard", comment: "Paste from Clipboard button")
    static let done = NSLocalizedString("done", bundle: Bundle.module, value: "Done", comment: "Done button")

    // Sync Set Up View
    // Begin Sync card
    static let beginSyncTitle = NSLocalizedString("preferences.begin-sync.card-title", bundle: Bundle.module, value: "Begin Syncing", comment: "Begin Syncing card title in sync settings")
    static let beginSyncDescription = NSLocalizedString("preferences.begin-sync.card-description", bundle: Bundle.module, value: "Securely sync bookmarks and passwords between your devices.", comment: "Begin Syncing card description in sync settings")
    static let beginSyncButton = NSLocalizedString("preferences.begin-sync.card-button", bundle: Bundle.module, value: "Sync With Another Device", comment: "Button text on the Begin Syncing card in sync settings")
    static let beginSyncFooter = NSLocalizedString("preferences.begin-sync.card-footer", bundle: Bundle.module, value: "Your data is end-to-end encrypted, and DuckDuckGo does not have access to the encryption key.", comment: "Footer / caption on the Begin Syncing card in sync settings")

    // Options
    static let otherOptionsSectionTitle = NSLocalizedString("preferences.other-options.section-title", bundle: Bundle.module, value: "Other Options", comment: "Sync settings. Other Options section title")
    static let syncThisDeviceLink = NSLocalizedString("preferences.sync-this-device.link-title", bundle: Bundle.module, value: "Sync and Back Up This Device", comment: "Sync settings. Title of a link to start setting up sync and backup the device")
    static let recoverDataLink = NSLocalizedString("preferences.recover-data.link-title", bundle: Bundle.module, value: "Recover Synced Data", comment: "Sync settings. Link to recover synced data.")

    // Preparing to sync dialog
    static let preparingToSyncDialogTitle = NSLocalizedString("preferences.preparing-to-sync.dialog-title", bundle: Bundle.module, value: "Preparing To Sync", comment: "Preparing to sync dialog title during sync set up")
    static let preparingToSyncDialogSubTitle = NSLocalizedString("preferences.preparing-to-sync.dialog-subtitle", bundle: Bundle.module, value: "We're setting up the connection to synchronize your bookmarks and saved logins with the other device.", comment: "Preparing to sync dialog subtitle during sync set up")
    static let preparingToSyncDialogAction = NSLocalizedString("preferences.preparing-to-sync.dialog-action", bundle: Bundle.module, value: "Connecting…", comment: "Sync preparing to sync dialog action")

    // Enter recovery code dialog
    static let enterRecoveryCodeDialogTitle = NSLocalizedString("preferences.enter-recovery-code.dialog-title", bundle: Bundle.module, value: "Enter Code", comment: "Sync enter recovery code dialog title")
    static let enterRecoveryCodeDialogSubtitle = NSLocalizedString("preferences.enter-recovery-code.dialog-subtitle", bundle: Bundle.module, value: "Enter the code on your Recovery PDF, or another synced device, to recover your synced data.", comment: "Sync enter recovery code dialog subtitle")
    static let enterRecoveryCodeDialogAction1 = NSLocalizedString("preferences.enter-recovery-code.dialog-action1", bundle: Bundle.module, value: "Paste Code Here", comment: "Sync enter recovery code dialog first possible action")
    static let enterRecoveryCodeDialogAction2 = NSLocalizedString("preferences.enter-recovery-code.dialog-action2", bundle: Bundle.module, value: "or scan QR code with a device that is still connected", comment: "Sync enter recovery code dialog second possible action")

    // Recover synced data dialog
    static let reciverSyncedDataDialogTitle = NSLocalizedString("preferences.recover-synced-data.dialog-title", bundle: Bundle.module, value: "Recover Synced Data", comment: "Sync recover synced data dialog title")
    static let reciverSyncedDataDialogSubitle = NSLocalizedString("preferences.recover-synced-data.dialog-subtitle", bundle: Bundle.module, value: "To restore your synced data, you'll need the Recovery Code you saved when you first set up Sync. This code may have been saved as a PDF on the device you originally used to set up Sync.", comment: "Recover synced data during Sync recovery process dialog subtitle")
    static let reciverSyncedDataDialogButton = NSLocalizedString("preferences.recover-synced-data.dialog-button", bundle: Bundle.module, value: "Get Started", comment: "Sync recover synced data dialog button")

    // Sync Title
    static let sync = NSLocalizedString("preferences.sync", bundle: Bundle.module, value: "Sync & Backup", comment: "Show sync preferences")
    static let syncRollOutBannerDescription = NSLocalizedString("preferences.sync.rollout-banner.description", bundle: Bundle.module, value: "Sync & Backup is rolling out gradually and may not be available yet within DuckDuckGo on your other devices.", comment: "Description of rollout banner")

    static let turnOff = NSLocalizedString("preferences.sync.turn-off", bundle: Bundle.module, value: "Turn Off", comment: "Turn off sync confirmation dialog button title")
    static let turnOffSync = NSLocalizedString("preferences.sync.turn-off.ellipsis", bundle: Bundle.module, value: "Turn Off Sync…", comment: "Disable sync button caption")

    // Sync Enabled View
    // Turn off sync dialog
    static let turnOffSyncConfirmTitle = NSLocalizedString("preferences.sync.turn-off.confirm.title", bundle: Bundle.module, value: "Turn off sync?", comment: "Turn off sync confirmation dialog title")
    static let turnOffSyncConfirmMessage = NSLocalizedString("preferences.sync.turn-off.confirm.message", bundle: Bundle.module, value: "This device will no longer be able to access your synced data.", comment: "Turn off sync confirmation dialog message")
    // Delete server data
    static let turnOffAndDeleteServerData = NSLocalizedString("preferences.sync.turn-off-and-delete-data", bundle: Bundle.module, value: "Turn Off and Delete Server Data…", comment: "Disable and delete data sync button caption")
    // sync connected
    static let syncConnected = NSLocalizedString("preferences.sync.connected", bundle: Bundle.module, value: "Sync Enabled", comment: "Sync state is enabled")
    // synced devices
    static let syncedDevices = NSLocalizedString("preferences.sync.synced-devices", bundle: Bundle.module, value: "Synced Devices", comment: "Settings section title")
    static let thisDevice = NSLocalizedString("preferences.sync.this-device", bundle: Bundle.module, value: "This Device", comment: "Indicator of a current user's device on the list")
    static let currentDeviceDetails = NSLocalizedString("preferences.sync.current-device-details", bundle: Bundle.module, value: "Details...", comment: "Sync Settings device details button")
    static let removeDeviceButton = NSLocalizedString("preferences.sync.remove-device", bundle: Bundle.module, value: "Remove...", comment: "Button to remove a device")

    // Remove device dialog
    static let removeDeviceConfirmTitle = NSLocalizedString("preferences.sync.remove-device-title", bundle: Bundle.module, value: "Remove device?", comment: "Title on remove a device confirmation")
    static let removeDeviceConfirmButton = NSLocalizedString("preferences.sync.remove-device-button", bundle: Bundle.module, value: "Remove Device", comment: "Button text on remove a device confirmation button")
    static func removeDeviceConfirmMessage(_ deviceName: String) -> String {
        let localized = NSLocalizedString("preferences.sync.remove-device-message",
                                          bundle: Bundle.module, value: "\"%@\" will no longer be able to access your synced data.",
                                          comment: "Message to confirm the device will no longer be able to access the synced data - devoce name item inserted")
        return String(format: localized, deviceName)
    }

    static let recovery = NSLocalizedString("prefrences.sync.recovery", bundle: Bundle.module, value: "Recovery", comment: "Sync settings section title")
    static let recoveryInstructions = NSLocalizedString("prefrences.sync.recovery-instructions", bundle: Bundle.module, value: "If you lose your device, you will need this recovery code to restore your synced data.", comment: "Instructions on how to restore synced data")

    // Sync with another device dialog
    static let syncWithAnotherDeviceTitle = NSLocalizedString("preferences.sync.sync-with-another-device.dialog-title", bundle: Bundle.module, value: "Sync With Another Device", comment: "Sync with another device dialog title")
    static func syncWithAnotherDeviceSubtitle(syncMenuPath: String) -> String {
        let localized = NSLocalizedString("preferences.sync.sync-with-another-device.dialog-subtitle1", bundle: Bundle.module, value: "Go to %@ in the DuckDuckGo Browser on another device and select Sync With Another Device.", comment: "Sync with another device dialog subtitle - Instruction with sync menu path item inserted")
        return String(format: localized, syncMenuPath)
    }
    static let syncMenuPath = NSLocalizedString("sync.menu.path", bundle: Bundle.module, value: "Settings › Sync & Backup", comment: "Sync Menu Path")
    static let syncWithAnotherDeviceShowCodeButton = NSLocalizedString("preferences.sync.sync-with-another-device.show-code-button", bundle: Bundle.module, value: "Show Code", comment: "Text on show code button on Sync with another device dialog")
    static let syncWithAnotherDeviceEnterCodeButton = NSLocalizedString("preferences.sync.sync-with-another-device.enter-code-button", bundle: Bundle.module, value: "Enter Code", comment: "Text on enter code button on Sync with another device dialog")
    static let syncWithAnotherDeviceShowQRCodeExplanation = NSLocalizedString("preferences.sync.sync-with-another-device.show-qr-code-explanation", bundle: Bundle.module, value: "Scan this QR code to connect.", comment: "Sync with another device dialog show qr code explanation")
    static let syncWithAnotherDeviceEnterCodeExplanation = NSLocalizedString("preferences.sync.sync-with-another-device.enter-code-explanation", bundle: Bundle.module, value: "Paste the code here to sync.", comment: "Sync with another device dialog enter code explanation")
    static let syncWithAnotherDeviceShowCodeExplanation = NSLocalizedString("preferences.sync.sync-with-another-device.show-code-explanation", bundle: Bundle.module, value: "Share this code to connect with a desktop machine.", comment: "Sync with another device dialog show code explanation")
    static let syncWithAnotherDeviceViewQRCode = NSLocalizedString("preferences.sync.sync-with-another-device.view-qr-code-link", bundle: Bundle.module, value: "View QR Code", comment: "Sync with another device dialog view qr code link")
    static let syncWithAnotherDeviceViewTextCode = NSLocalizedString("preferences.sync.sync-with-another-device.view-text-code-link", bundle: Bundle.module, value: "View Text Code", comment: "Sync with another device dialog view text code link")

    // Save recovery PDF dialog
    static let saveRecoveryPDF = NSLocalizedString("prefrences.sync.save-recovery-pdf", bundle: Bundle.module, value: "Save Your Recovery Code", comment: "Caption for a button to save Sync recovery PDF")
    static let recoveryPDFExplanation = NSLocalizedString("prefrences.sync.recovery-pdf-explanation", bundle: Bundle.module, value: "If you lose access to your devices, you will need this code to recover your synced data. You can save this code to your device as a PDF.", comment: "Sync recovery PDF explanation")
    static let recoveryPDFCopyCodeButton = NSLocalizedString("prefrences.sync.recovery-pdf-copy-code-button", bundle: Bundle.module, value: "Copy Code", comment: "Sync recovery PDF copy code button")
    static let recoveryPDFSavePDFButton = NSLocalizedString("prefrences.sync.recovery-pdf-save-pdf-button", bundle: Bundle.module, value: "Save PDF", comment: "Sync recovery PDF save pdf button")
    static let recoveryPDFWarning = NSLocalizedString("prefrences.sync.recovery-pdf-warning", bundle: Bundle.module, value: "Anyone with access to this code can access your synced data, so please keep it in a safe place.", comment: "Sync recovery PDF warning")

    // Sync with server dialog
    static let syncWithServerTitle = NSLocalizedString("preferences.sync.sync-with-server-title", bundle: Bundle.module, value: "Sync and Back Up This Device", comment: "Sync with server dialog title")
    static let syncWithServerSubtitle1 = NSLocalizedString("preferences.sync.sync-with-server-subtitle1", bundle: Bundle.module, value: "This creates an encrypted backup of your bookmarks and passwords on DuckDuckGo’s secure server, which can be synced with your other devices.", comment: "Sync with server dialog first subtitle")
    static let syncWithServerSubtitle2 = NSLocalizedString("preferences.sync.sync-with-server-subtitle2", bundle: Bundle.module, value: "The encryption key is only stored on your device, DuckDuckGo cannot access it.", comment: "Sync with server dialog second subtitle")
    static let syncWithServerButton = NSLocalizedString("preferences.sync.sync-with-server-button", bundle: Bundle.module, value: "Turn On Sync & Backup", comment: "Sync with server dialog button")

    // Device synced dialog
    static let deviceSynced = NSLocalizedString("prefrences.sync.device-synced", bundle: Bundle.module, value: "Your data is synced!", comment: "Sync setup confirmation dialog title")

    // Device details
    static let deviceDetailsTitle = NSLocalizedString("prefrences.sync.device-details.title", bundle: Bundle.module, value: "Device Details", comment: "The title of the device details dialog")
    static let deviceDetailsLabel = NSLocalizedString("prefrences.sync.device-details.label", bundle: Bundle.module, value: "Name", comment: "The text entry label to name the device")
    static let deviceDetailsPrompt = NSLocalizedString("prefrences.sync.device-details.prompt", bundle: Bundle.module, value: "Device name", comment: "The text entry prompt to name the device")

    // Delete Account Dialog
    static let deleteAccountTitle = NSLocalizedString("prefrences.sync.delete-account.title", bundle: Bundle.module, value: "Delete server data?", comment: "Title for delete account confirmation pop up")
    static let deleteAccountMessage = NSLocalizedString("prefrences.sync.delete-account.message", bundle: Bundle.module, value: "These devices will be disconnected and your synced data will be deleted from the server.", comment: "Message for delete account confirmation pop up")
    static let deleteAccountButton = NSLocalizedString("prefrences.sync.delete-account.button", bundle: Bundle.module, value: "Delete Data", comment: "Label for delete account button")

    // Sync enabled options
    static let optionsSectionTitle = NSLocalizedString("prefrences.sync.options-section-title", bundle: Bundle.module, value: "Options", comment: "Title for options settings")
    static let shareFavoritesOptionTitle = NSLocalizedString("prefrences.sync.share-favorite-option-title", bundle: Bundle.module, value: "Unify Favorites Across Devices", comment: "Title for share favorite option")
    static let shareFavoritesOptionCaption = NSLocalizedString("prefrences.sync.share-favorite-option-caption", bundle: Bundle.module, value: "Use the same favorite bookmarks on all your devices. Leave off to keep mobile and desktop favorites separate.", comment: "Caption for share favorite option")
    static let fetchFaviconsOptionTitle = NSLocalizedString("prefrences.sync.fetch-favicons-option-title", bundle: Bundle.module, value: "Auto-Download Icons", comment: "Title for fetch favicons option")
    static let fetchFaviconsOptionCaption = NSLocalizedString("prefrences.sync.fetch-favicons-option-caption", bundle: Bundle.module, value: "Automatically download icons for synced bookmarks. Icon downloads are exposed to your network.", comment: "Caption for fetch favicons option")

    // sync enabled errors
    static let syncLimitExceededTitle = NSLocalizedString("prefrences.sync.limit-exceeded-title", bundle: Bundle.module, value: "Sync Paused", comment: "Title for sync limits exceeded warning")
    static let bookmarksLimitExceededDescription = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-description", bundle: Bundle.module, value: "Bookmark limit exceeded. Delete some to resume syncing.", comment: "Description for sync bookmarks limits exceeded warning")
    static let credentialsLimitExceededDescription = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-description", bundle: Bundle.module, value: "Logins limit exceeded. Delete some to resume syncing.", comment: "Description for sync credentials limits exceeded warning")
    static let bookmarksLimitExceededAction = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-action", bundle: Bundle.module, value: "Manage Bookmarks", comment: "Button title for sync bookmarks limits exceeded warning to go to manage bookmarks")
    static let credentialsLimitExceededAction = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-action", bundle: Bundle.module, value: "Manage passwords…", comment: "Button title for sync credentials limits exceeded warning to go to manage passwords")
    static let invalidBookmarksPresentTitle = NSLocalizedString("prefrences.sync.invalid-bookmarks-present-title", bundle: Bundle.module, value: "Some bookmarks are not syncing due to excessively long content in certain fields.", comment: "Alert title for invalid bookmarks being filtered out of synced data")
    static let invalidCredentialsPresentTitle = NSLocalizedString("prefrences.sync.invalid-credentials-present-title", bundle: Bundle.module, value: "Some logins are not syncing due to excessively long content in certain fields.", comment: "Alert title for invalid logins being filtered out of synced data")

    static func invalidBookmarksPresentDescription(_ invalidItemTitle: String, numberOfInvalidItems: Int) -> String {
        guard numberOfInvalidItems > 1 else {
            let message = NSLocalizedString(
                "prefrences.sync.invalid-bookmarks-present-description-one",
                bundle: Bundle.module,
                value: "Your bookmark for %@ can't sync because one of its fields exceeds the character limit.",
                comment: "Alert message for 1 invalid bookmark being filtered out of synced data"
            )
            return String(format: message, invalidItemTitle)
        }
        let message = NSLocalizedString(
            "prefrences.sync.invalid-bookmarks-present-description-many",
            bundle: Bundle.module,
            value: "Some bookmarks (%d) can't sync because some of their fields exceed the character limit.",
            comment: "Alert message for multiple invalid bookmark being filtered out of synced data"
        )
        return String(format: message, numberOfInvalidItems)
    }

    static func invalidCredentialsPresentDescription(_ invalidItemTitle: String, numberOfInvalidItems: Int) -> String {
        guard numberOfInvalidItems > 1 else {
            let message = NSLocalizedString(
                "prefrences.sync.invalid-credentials-present-description-one",
                bundle: Bundle.module,
                value: "Your password for %@ can't sync because one of its fields exceeds the character limit.",
                comment: "Alert message for 1 invalid login being filtered out of synced data"
            )
            return String(format: message, invalidItemTitle)
        }
        let message = NSLocalizedString(
            "prefrences.sync.invalid-credentials-present-description-many",
            bundle: Bundle.module,
            value: "Some passwords (n) can't sync because some of their fields exceed the character limit.",
            comment: "Alert message for multiple invalid logins being filtered out of synced data"
        )
        return String(format: message, numberOfInvalidItems)
    }

    static let syncErrorAlertTitle = NSLocalizedString("alert.sync-error", bundle: Bundle.module, value: "Sync & Backup Error", comment: "Title for sync error alert")
    static let syncDeviceAuthenticationErrorAlertTitle = NSLocalizedString("alert.sync-device-auth-error", bundle: Bundle.module, value: "Sync & Backup Error", comment: "Title for an error alert")
    static let syncDeviceAuthenticationErrorAlertButton = NSLocalizedString("alert.sync-device-auth-error-button", bundle: Bundle.module, value: "Go to Settings", comment: "Button Title of an error alert")
    static let unableToAuthenticateDevice = NSLocalizedString("alert.unable-to-authenticate-device", bundle: Bundle.module, value: "A device password is required to use Sync & Backup.", comment: "Description for  unable to authenticate error")
    static let unableToSyncToServerDescription = NSLocalizedString("alert.unable-to-sync-to-server-description", bundle: Bundle.module, value: "Unable to connect to the server.", comment: "Description for unable to sync to server error")
    static let unableToSyncWithAnotherDeviceDescription = NSLocalizedString("alert.unable-to-sync-with-another-device-description", bundle: Bundle.module, value: "Unable to Sync with another device.", comment: "Description for unable to sync with another device error")
    static let unableToMergeTwoAccountsDescription = NSLocalizedString("alert.unable-to-merge-two-accounts-description", bundle: Bundle.module, value: "To pair these devices, turn off Sync & Backup on one device then tap \"Sync With Another Device\" on the other device.", comment: "Description for unable to merge two accounts error")
    static let unableToUpdateDeviceNameDescription = NSLocalizedString("alert.unable-to-update-device-name-description", bundle: Bundle.module, value: "Unable to update the device name.", comment: "Description for unable to update device name error")
    static let unableToTurnSyncOffDescription = NSLocalizedString("alert.unable-to-turn-sync-off-description", bundle: Bundle.module, value: "Unable to turn Sync & Backup off.", comment: "Description for unable to turn sync off error")
    static let unableToDeleteDataDescription = NSLocalizedString("alert.unable-to-delete-data-description", bundle: Bundle.module, value: "Unable to delete data on the server.", comment: "Description for unable to delete data error")
    static let unableToRemoveDeviceDescription = NSLocalizedString("alert.unable-to-remove-device-description", bundle: Bundle.module, value: "Unable to remove this device from Sync & Backup.", comment: "Description for unable to remove device error")
    static let invalidCodeDescription = NSLocalizedString("alert.invalid-code-description", bundle: Bundle.module, value: "Sorry, this code is invalid. Please make sure it was entered correctly.", comment: "Description for invalid code error")
    static let unableCreateRecoveryPdfDescription = NSLocalizedString("alert.unable-to-create-recovery-pdf-description", bundle: Bundle.module, value: "Unable to create the recovery PDF.", comment: "Description for unable to create recovery pdf error")

    public static let syncAlertSwitchAccountTitle = NSLocalizedString("alert.sync-switch-account-button", value: "Switch to a different Sync?", comment: "Switch account title in alert")
    public static let syncAlertSwitchAccountMessage = NSLocalizedString("alert.sync-switch-account-message", value: "This device is already synced, are you sure you want to sync it with a different backup or device? Switching won't remove any data already synced to this device.", comment: "Description for switching sync accounts when there's two")
    public static let syncAlertSwitchAccountButton = NSLocalizedString("alert.sync-switch-sync-button", value: "Switch Sync", comment: "Switch account button in alert")

    static let fetchFaviconsOnboardingTitle = NSLocalizedString("prefrences.sync.fetch-favicons-onboarding-title", bundle: Bundle.module, value: "Download Missing Icons?", comment: "Title for fetch favicons onboarding dialog")
    static let fetchFaviconsOnboardingMessage = NSLocalizedString("prefrences.sync.fetch-favicons-onboarding-message", bundle: Bundle.module, value: "Do you want this device to automatically download icons for any new bookmarks synced from your other devices? This will expose the download to your network any time a bookmark is synced.", comment: "Text for fetch favicons onboarding dialog")
    static let keepFaviconsUpdated = NSLocalizedString("prefrences.sync.keep-favicons-updated", bundle: Bundle.module, value: "Keep Bookmarks Icons Updated", comment: "Title of the confirmation button for favicons fetching")

    // Sync Feature Flags
    static let syncUnavailableTitle = NSLocalizedString("sync.warning.sync-unavailable", bundle: Bundle.module, value: "Sync & Backup is Unavailable", comment: "Title of the warning message that sync and backup are unavailable")
    static let syncPausedTitle = NSLocalizedString("sync.warning.sync-paused", bundle: Bundle.module, value: "Sync & Backup is Paused", comment: "Title of the warning message that Sync & Backup is Paused")
    static let syncUnavailableMessage = NSLocalizedString("sync.warning.sync-unavailable-message", bundle: Bundle.module, value: "Sorry, but Sync & Backup is currently unavailable. Please try again later.", comment: "Data syncing unavailable warning message")
    static let syncUnavailableMessageUpgradeRequired = NSLocalizedString("sync.warning.data-syncing-disabled-upgrade-required", bundle: Bundle.module, value: "Sorry, but Sync & Backup is no longer available in this app version. Please update DuckDuckGo to the latest version to continue.", comment: "Data syncing unavailable warning message")
}
