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
    static let pasteFromClipboard = NSLocalizedString("paste-from-clipboard", value: "Paste from Clipboard", comment: "Paste button")
    static let done = NSLocalizedString("done", value: "Done", comment: "Done button")

    // Sync Set Up View
    // Begin Sync card
    static let beginSyncTitle = NSLocalizedString("preferences.begin.sync-card-title", value: "Begin Syncing", comment: "Begin Syncing card title in sync settings")
    static let beginSyncDescription = NSLocalizedString("preferences.begin.sync-card-description", value: "Securely sync bookmarks and passwords between your devices.", comment: "Begin Syncing card description in sync settings")
    static let beginSyncButton = NSLocalizedString("preferences.begin.sync-card-button", value: "Sync with Another Device", comment: "Begin Syncing card button in sync settings")
    // Options
    static let otherOptionsSectionTitle = NSLocalizedString("preferences.other-options.section-title", value: "Other Options", comment: "Sync preferences other options section title")
    static let syncThisDeviceLink = NSLocalizedString("preferences.sync-this-device.link-title", value: "Sync and Back Up This Device", comment: "Sync preferences sync this device link title")
    static let recoverDataLink = NSLocalizedString("preferences.recover-data.link-title", value: "Recover Synced Data", comment: "Sync preferences recover data link title")

    // Preparing to sync dialog
    static let preparingToSyncDialogTitle = NSLocalizedString("preferences.preparing-to-sync.dialog-title", value: "Setting Up Sync \nand Backup", comment: "Sync preparing to sync dialog title")
    static let preparingToSyncDialogSubTitle = NSLocalizedString("preferences.preparing-to-sync.dialog-subtitle", value: "Your bookmarks and passwords are being prepared to sync. This should only take a moment.", comment: "Sync preparing to sync dialog subtitle")
    static let preparingToSyncDialogAction = NSLocalizedString("preferences.preparing-to-sync.dialog-action", value: "Connecting…", comment: "Sync preparing to sync dialog action")

    // Enter recovery code dialog
    static let enterRecoveryCodeDialogTitle = NSLocalizedString("preferences.enter-recovery-code.dialog-title", value: "Enter Code", comment: "Sync enter recovery code dialog title")
    static let enterRecoveryCodeDialogSubtitle = NSLocalizedString("preferences.enter-recovery-code.dialog-subtitle", value: "Enter the code on your Recovery PDF, or another synced device, to recover your synced data.", comment: "Sync enter recovery code dialog subtitle")
    static let enterRecoveryCodeDialogAction1 = NSLocalizedString("preferences.enter-recovery-code.dialog-action1", value: "Paste Code Here", comment: "Sync enter recovery code dialog first possible action")
    static let enterRecoveryCodeDialogAction2 = NSLocalizedString("preferences.enter-recovery-code.dialog-action2", value: "or scan QR code with a device that is still connected", comment: "Sync enter recovery code dialog second possible action")

    // Your data is returning dialog
    static let yourDataIsReturningDialogTitle = NSLocalizedString("preferences.your-data-is-returning.dialog-title", value: "Your Data is Returning!", comment: "Sync your data is returning dialog title")
    static let yourDataIsReturningDialogSubtitle = NSLocalizedString("preferences.your-data-is-returning.dialog-subtitle", value: "Your bookmarks and logins will now be restored from DuckDuckGo's secure server.", comment: "Sync your data is returning dialog subtitle")
    static let yourDataIsReturningDialogAction = NSLocalizedString("preferences.your-data-is-returning.dialog-action", value: "Downloading…", comment: "Sync preparing to sync dialog action")

    // Recover synced data dialog
    static let reciverSyncedDataDialogTitle = NSLocalizedString("preferences.recover-synced-data.dialog-title", value: "Recover Synced Data", comment: "Sync recover synced data dialog title")
    static let reciverSyncedDataDialogSubitle = NSLocalizedString("preferences.recover-synced-data.dialog-subtitle", value: "To restore your synced data, you'll need the \"Recovery Code\" you saved when you first set up the sync. This code may have been saved as a PDF with a QR code or as a text code.", comment: "Sync recover synced data dialog subtitle")
    static let reciverSyncedDataDialogButton = NSLocalizedString("preferences.recover-synced-data.dialog-button", value: "Enter Code", comment: "Sync recover synced data dialog button")

    // Sync Title
    static let sync = NSLocalizedString("preferences.sync", value: "Sync and Back Up", comment: "Show sync preferences")

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

    // Save recovery PDF dialog
    static let saveRecoveryPDF = NSLocalizedString("prefrences.sync.save-recovery-pdf", value: "Save Your Recovery Code", comment: "Caption for a button to save Sync recovery PDF")
    static let recoveryPDFExplanation = NSLocalizedString("prefrences.sync.recovery-pdf-explanation", value: "If you lose access to your devices, you will need this code to recover your synced data. You can save this code to your device as a PDF.", comment: "Sync recovery PDF explanation")
    static let recoveryPDFCopyCodeButton = NSLocalizedString("prefrences.sync.recovery-pdf-copy-code-button", value: "Copy Code", comment: "Sync recovery PDF copy code button")
    static let recoveryPDFSavePDFButton = NSLocalizedString("prefrences.sync.recovery-pdf-save-pdf-button", value: "Save PDF", comment: "Sync recovery PDF save pdf button")
    static let recoveryPDFWarning = NSLocalizedString("prefrences.sync.recovery-pdf-warning", value: "Anyone with access to this code can access your synced data, so please keep it in a safe place.", comment: "Sync recovery PDF warning")

    // Sync with server dialog
    static let syncWithServerTitle = NSLocalizedString("preferences.sync.sync-with-server-title", value: "Sync and Back Up This Device", comment: "Sync with server dialog title")
    static let syncWithServerSubtitle1 = NSLocalizedString("preferences.sync.sync-with-server-subtitle1", value: "Your bookmarks and saved logins will be encrypted and begin syncing with DuckDuckGo's server.", comment: "Sync with server dialog first subtitle")
    static let syncWithServerSubtitle2 = NSLocalizedString("preferences.sync.sync-with-server-subtitle2", value: "Only your device holds the decryption key; DuckDuckGo cannot access it.", comment: "Sync with server dialog second subtitle")
    static let syncWithServerButton = NSLocalizedString("preferences.sync.sync-with-server-button", value: "Turn on Sync", comment: "Sync with server dialog button")

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

    // sync enabled errors
    static let syncLimitExceededTitle = NSLocalizedString("prefrences.sync.limit-exceeded-title", value: "Sync Paused", comment: "Title for sync limits exceeded warning")
    static let bookmarksLimitExceededDescription = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-description", value: "Bookmark limit exceeded. Delete some to resume syncing.", comment: "Description for sync bookmarks limits exceeded warning")
    static let credentialsLimitExceededDescription = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-description", value: "Logins limit exceeded. Delete some to resume syncing.", comment: "Description for sync credentials limits exceeded warning")
    static let bookmarksLimitExceededAction = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-action", value: "Manage Bookmarks", comment: "Button title for sync bookmarks limits exceeded warning to manage bookmarks")
    static let credentialsLimitExceededAction = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-action", value: "Manage Logins", comment: "Button title for sync credentials limits exceeded warning to manage logins")
}
