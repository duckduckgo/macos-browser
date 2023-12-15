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
    static let ok = NSLocalizedString("ok", value: "OK", comment: "OK button")
    static let notNow = NSLocalizedString("notnow", value: "Not Now", comment: "Not Now button")
    static let cancel = NSLocalizedString("cancel", value: "Cancel", comment: "Cancel button")
    static let submit = NSLocalizedString("submit", value: "Submit", comment: "Submit button")
    static let next = NSLocalizedString("next", value: "Next", comment: "Next button")
    static let copy = NSLocalizedString("copy", value: "Copy", comment: "Copy button")
    static let share = NSLocalizedString("share", value: "Share", comment: "Share button")
    static let paste = NSLocalizedString("paste", value: "Paste", comment: "Paste button")
    static let pasteFromClipboard = NSLocalizedString("paste-from-clipboard", value: "Paste from Clipboard", comment: "Paste button")
    static let done = NSLocalizedString("done", value: "Done", comment: "Done button")

    // Sync Set Up View
    // Begin Sync card
    static let beginSyncTitle = NSLocalizedString("preferences.begin.sync-card-title", value: "Begin Syncing", comment: "Begin Syncing card title in sync settings")
    static let beginSyncDescription = NSLocalizedString("preferences.begin.sync-card-description", value: "Securely sync bookmarks and passwords between your devices.", comment: "Begin Syncing card description in sync settings")
    static let beginSyncButton = NSLocalizedString("preferences.begin.sync-card-button", value: "Sync with Another Device", comment: "Begin Syncing card button in sync settings")
    static let beginSyncFooter = NSLocalizedString("preferences.begin.sync-card-footer", value: "Your data is end-to-end encrypted, and DuckDuckGo does not have access to the encryption key.", comment: "Begin Syncing card footer in sync settings")
    // Options
    static let otherOptionsSectionTitle = NSLocalizedString("preferences.other-options.section-title", value: "Other Options", comment: "Sync preferences other options section title")
    static let syncThisDeviceLink = NSLocalizedString("preferences.sync-this-device.link-title", value: "Sync and Back Up This Device", comment: "Sync preferences sync this device link title")
    static let recoverDataLink = NSLocalizedString("preferences.recover-data.link-title", value: "Recover Synced Data", comment: "Sync preferences recover data link title")

    // Preparing to sync dialog
    static let preparingToSyncDialogTitle = NSLocalizedString("preferences.preparing-to-sync.dialog-title", value: "Preparing to Sync", comment: "Sync preparing to sync dialog title")
    static let preparingToSyncDialogSubTitle = NSLocalizedString("preferences.preparing-to-sync.dialog-subtitle", value: "We're setting up the connection to synchronize your bookmarks and saved logins with the other device.", comment: "Sync preparing to sync dialog subtitle")
    static let preparingToSyncDialogAction = NSLocalizedString("preferences.preparing-to-sync.dialog-action", value: "Connecting…", comment: "Sync preparing to sync dialog action")

    // Enter recovery code dialog
    static let enterRecoveryCodeDialogTitle = NSLocalizedString("preferences.enter-recovery-code.dialog-title", value: "Enter Code", comment: "Sync enter recovery code dialog title")
    static let enterRecoveryCodeDialogSubtitle = NSLocalizedString("preferences.enter-recovery-code.dialog-subtitle", value: "Enter the code on your Recovery PDF, or another synced device, to recover your synced data.", comment: "Sync enter recovery code dialog subtitle")
    static let enterRecoveryCodeDialogAction1 = NSLocalizedString("preferences.enter-recovery-code.dialog-action1", value: "Paste Code Here", comment: "Sync enter recovery code dialog first possible action")
    static let enterRecoveryCodeDialogAction2 = NSLocalizedString("preferences.enter-recovery-code.dialog-action2", value: "or scan QR code with a device that is still connected", comment: "Sync enter recovery code dialog second possible action")

    // Recover synced data dialog
    static let reciverSyncedDataDialogTitle = NSLocalizedString("preferences.recover-synced-data.dialog-title", value: "Recover Synced Data", comment: "Sync recover synced data dialog title")
    static let reciverSyncedDataDialogSubitle = NSLocalizedString("preferences.recover-synced-data.dialog-subtitle", value: "To restore your synced data, you'll need the Recovery Code you saved when you first set up Sync. This code may have been saved as a PDF on the device you originally used to set up Sync.", comment: "Sync recover synced data dialog subtitle")
    static let reciverSyncedDataDialogButton = NSLocalizedString("preferences.recover-synced-data.dialog-button", value: "Get Started", comment: "Sync recover synced data dialog button")

    // Sync Title
    static let sync = NSLocalizedString("preferences.sync", value: "Sync & Backup", comment: "Show sync preferences")

    static let turnOff = NSLocalizedString("preferences.sync.turn-off", value: "Turn Off", comment: "Turn off sync confirmation dialog button title")
    static let turnOffSync = NSLocalizedString("preferences.sync.turn-off.ellipsis", value: "Turn off Sync...", comment: "Disable sync button caption")

    // Sync Enabled View
    // Turn off sync dialog
    static let turnOffSyncConfirmTitle = NSLocalizedString("preferences.sync.turn-off.confirm.title", value: "Turn Off Sync?", comment: "Turn off sync confirmation dialog title")
    static let turnOffSyncConfirmMessage = NSLocalizedString("preferences.sync.turn-off.confirm.message", value: "This device will no longer be able to access your synced data.", comment: "Turn off sync confirmation dialog message")
    // Delete server data
    static let turnOffAndDeleteServerData = NSLocalizedString("preferences.sync.turn-off-and-delete-data", value: "Turn Off and Delete Server Data", comment: "Disable and delete data sync button caption")
    // sync connected
    static let syncConnected = NSLocalizedString("preferences.sync.connected", value: "Sync Enabled", comment: "Sync state")
    // synced devices
    static let syncedDevices = NSLocalizedString("preferences.sync.synced-devices", value: "Synced Devices", comment: "Settings section title")
    static let thisDevice = NSLocalizedString("preferences.sync.this-device", value: "This Device", comment: "Indicator of a current user's device on the list")
    static let currentDeviceDetails = NSLocalizedString("preferences.sync.current-device-details", value: "Details...", comment: "Sync Settings device details button")
    static let removeDeviceButton = NSLocalizedString("preferences.sync.remove-device", value: "Remove...", comment: "Button to remove a device")

    // Remove device dialog
    static let removeDeviceConfirmTitle = NSLocalizedString("preferences.sync.remove-device-title", value: "Remove Device?", comment: "Title on remove a device confirmation")
    static let removeDeviceConfirmButton = NSLocalizedString("preferences.sync.remove-device-button", value: "Remove Device", comment: "Button to on remove a device confirmation")
    static func removeDeviceConfirmMessage(_ deviceName: String) -> String {
        let localized = NSLocalizedString("preferences.sync.remove-device-message",
                                          value: "\"%@\" will no longer be able to access your synced data.",
                                          comment: "")
        return String(format: localized, deviceName)
    }

    static let recovery = NSLocalizedString("prefrences.sync.recovery", value: "Recovery", comment: "Sync settings section title")
    static let recoveryInstructions = NSLocalizedString("prefrences.sync.recovery-instructions", value: "If you lose your device, you will need this recovery code to restore your synced data.", comment: "Instructions on how to restore synced data")

    // Sync with another device dialog
    static let syncWithAnotherDeviceTitle = NSLocalizedString("preferences.sync.sync-with-another-device.dialog-title", value: "Sync with Another Device", comment: "Sync with another device dialog title")
    static let syncWithAnotherDeviceSubtitle1 = NSLocalizedString("preferences.sync.sync-with-another-device.dialog-subtitle1", value: "Go to ", comment: "Sync with another device dialog subtitle first part")
    static let syncWithAnotherDeviceSubtitle2 = NSLocalizedString("preferences.sync.sync-with-another-device.dialog-subtitle2", value: "Settings › Sync ", comment: "Sync with another device dialog subtitle second part")
    static let syncWithAnotherDeviceSubtitle3 = NSLocalizedString("preferences.sync.sync-with-another-device.dialog-subtitle3", value: "in the DuckDuckGo Browser on a another device and select Sync with Another Device.", comment: "Sync with another device dialog subtitle thisrd part")
    static let syncWithAnotherDeviceShowCodeButton = NSLocalizedString("preferences.sync.sync-with-another-device.show-code-button", value: "Show Code", comment: "Sync with another device dialog show code button")
    static let syncWithAnotherDeviceEnterCodeButton = NSLocalizedString("preferences.sync.sync-with-another-device.enter-code-button", value: "Enter Code", comment: "Sync with another device dialog enter code button")
    static let syncWithAnotherDeviceShowQRCodeExplanation = NSLocalizedString("preferences.sync.sync-with-another-device.show-qr-code-explanation", value: "Scan this QR code to connect.", comment: "Sync with another device dialog show qr code explanation")
    static let syncWithAnotherDeviceEnterCodeExplanation = NSLocalizedString("preferences.sync.sync-with-another-device.enter-code-explanation", value: "Enter the text code in the field below to connect.", comment: "Sync with another device dialog enter code explanation")
    static let syncWithAnotherDeviceShowCodeExplanation = NSLocalizedString("preferences.sync.sync-with-another-device.show-code-explanation", value: "Share this code to connect with a desktop machine.", comment: "Sync with another device dialog show code explanation")
    static let syncWithAnotherDeviceViewQRCode = NSLocalizedString("preferences.sync.sync-with-another-device.view-qr-code-link", value: "View QR Code", comment: "Sync with another device dialog view qr code link")
    static let syncWithAnotherDeviceViewTextCode = NSLocalizedString("preferences.sync.sync-with-another-device.view-text-code-link", value: "View Text Code", comment: "Sync with another device dialog view text code link")

    // Save recovery PDF dialog
    static let saveRecoveryPDF = NSLocalizedString("prefrences.sync.save-recovery-pdf", value: "Save Your Recovery Code", comment: "Caption for a button to save Sync recovery PDF")
    static let recoveryPDFExplanation = NSLocalizedString("prefrences.sync.recovery-pdf-explanation", value: "If you lose access to your devices, you will need this code to recover your synced data. You can save this code to your device as a PDF.", comment: "Sync recovery PDF explanation")
    static let recoveryPDFCopyCodeButton = NSLocalizedString("prefrences.sync.recovery-pdf-copy-code-button", value: "Copy Code", comment: "Sync recovery PDF copy code button")
    static let recoveryPDFSavePDFButton = NSLocalizedString("prefrences.sync.recovery-pdf-save-pdf-button", value: "Save PDF", comment: "Sync recovery PDF save pdf button")
    static let recoveryPDFWarning = NSLocalizedString("prefrences.sync.recovery-pdf-warning", value: "Anyone with access to this code can access your synced data, so please keep it in a safe place.", comment: "Sync recovery PDF warning")

    // Sync with server dialog
    static let syncWithServerTitle = NSLocalizedString("preferences.sync.sync-with-server-title", value: "Sync and Back Up This Device", comment: "Sync with server dialog title")
    static let syncWithServerSubtitle1 = NSLocalizedString("preferences.sync.sync-with-server-subtitle1", value: "This creates an encrypted backup of your bookmarks and passwords on DuckDuckGo’s secure server, which can be synced with your other devices.", comment: "Sync with server dialog first subtitle")
    static let syncWithServerSubtitle2 = NSLocalizedString("preferences.sync.sync-with-server-subtitle2", value: "The encryption key is only stored on your device, DuckDuckGo cannot access it.", comment: "Sync with server dialog second subtitle")
    static let syncWithServerButton = NSLocalizedString("preferences.sync.sync-with-server-button", value: "Turn on Sync & Backup", comment: "Sync with server dialog button")

    // Device synced dialog
    static let deviceSynced = NSLocalizedString("prefrences.sync.device-synced", value: "Your Data is Synced!", comment: "Sync setup dialog title")

    // Device details
    static let deviceDetailsTitle = NSLocalizedString("prefrences.sync.device-details.title", value: "Device Details", comment: "The title of the device details dialog")
    static let deviceDetailsLabel = NSLocalizedString("prefrences.sync.device-details.label", value: "Name", comment: "The text entry label")
    static let deviceDetailsPrompt = NSLocalizedString("prefrences.sync.device-details.prompt", value: "Device name", comment: "The text entry prompt")

    // Delete Account Dialog
    static let deleteAccountTitle = NSLocalizedString("prefrences.sync.delete-account.title", value: "Delete Server Data?", comment: "Title for delete account")
    static let deleteAccountMessage = NSLocalizedString("prefrences.sync.delete-account.message", value: "These devices will be disconnected and your synced data will be deleted from the server.", comment: "Message for delete account")
    static let deleteAccountButton = NSLocalizedString("prefrences.sync.delete-account.button", value: "Delete Data", comment: "Label for delete account button")

    // Sync enabled options
    static let optionsSectionTitle = NSLocalizedString("prefrences.sync.options-section-title", value: "Options", comment: "Title for options settings")
    static let shareFavoritesOptionTitle = NSLocalizedString("prefrences.sync.share-favorite-option-title", value: "Unify Favorites Across Devices", comment: "Title for share favorite option")
    static let shareFavoritesOptionCaption = NSLocalizedString("prefrences.sync.share-favorite-option-caption", value: "Use the same favorite bookmarks on the new tab. Leave off to keep mobile and desktop favorites separate.", comment: "Caption for share favorite option")
    static let fetchFaviconsOptionTitle = NSLocalizedString("prefrences.sync.fetch-favicons-option-title", value: "Fetch Bookmark Icons", comment: "Title for fetch favicons option")
    static let fetchFaviconsOptionCaption = NSLocalizedString("prefrences.sync.fetch-favicons-option-caption", value: "Automatically download icons for synced bookmarks.", comment: "Caption for fetch favicons option")

    // sync enabled errors
    static let syncLimitExceededTitle = NSLocalizedString("prefrences.sync.limit-exceeded-title", value: "Sync Paused", comment: "Title for sync limits exceeded warning")
    static let bookmarksLimitExceededDescription = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-description", value: "Bookmark limit exceeded. Delete some to resume syncing.", comment: "Description for sync bookmarks limits exceeded warning")
    static let credentialsLimitExceededDescription = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-description", value: "Logins limit exceeded. Delete some to resume syncing.", comment: "Description for sync credentials limits exceeded warning")
    static let bookmarksLimitExceededAction = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-action", value: "Manage Bookmarks", comment: "Button title for sync bookmarks limits exceeded warning to manage bookmarks")
    static let credentialsLimitExceededAction = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-action", value: "Manage passwords...", comment: "Button title for sync credentials limits exceeded warning to manage logins")
    static let syncErrorAlertTitle = NSLocalizedString("alert.sync-error", value: "Sync Error", comment: "Title for sync error alert")
    static let unableToSyncDescription = NSLocalizedString("alert.unable-to-sync-description", value: "Unable to sync.", comment: "Description for unable to sync error")
    static let unableToGetDevicesDescription = NSLocalizedString("alert.unable-to-get-devices-description", value: "Unable to retrieve the list of connected devices.", comment: "Description for unable to get devices error")
    static let unableToUpdateDeviceNameDescription = NSLocalizedString("alert.unable-to-update-device-name-description", value: "Unable to update the name of the device.", comment: "Description for unable to update device name error")
    static let unableToTurnSyncOffDescription = NSLocalizedString("alert.unable-to-turn-sync-off-description", value: "Unable to turn sync off.", comment: "Description for unable to turn sync off error")
    static let unableToDeleteDataDescription = NSLocalizedString("alert.unable-to-delete-data-description", value: "Unable to delete data on the server.", comment: "Description for unable to delete data error")
    static let unableToRemoveDeviceDescription = NSLocalizedString("alert.unable-to-remove-device-description", value: "Unable to remove the specified device from the synchronized devices.", comment: "Description for unable to remove device error")
    static let invalidCodeDescription = NSLocalizedString("alert.invalid-code-description", value: "The code used is invalid.", comment: "Description for invalid code error")
    static let unableCreateRecoveryPdfDescription = NSLocalizedString("alert.unable-to-create-recovery-pdf-description", value: "There was a problem creating the recovery PDF.", comment: "Description for unable to create recovery pdf error")

    static let fetchFaviconsOnboardingTitle = NSLocalizedString("prefrences.sync.fetch-favicons-onboarding-title", value: "Download Missing Icons?", comment: "Title for fetch favicons onboarding dialog")
    static let fetchFaviconsOnboardingMessage = NSLocalizedString("prefrences.sync.fetch-favicons-onboarding-message", value: "Do you want this device to automatically download icons for any new bookmarks synced from your other devices? This will expose the download to your network any time a bookmark is synced.", comment: "Text for fetch favicons onboarding dialog")
    static let keepFaviconsUpdated = NSLocalizedString("prefrences.sync.keep-favicons-updated", value: "Keep Bookmarks Icons Updated", comment: "Title of the confirmation button for favicons fetching")
}
