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

    static let ok = NSLocalizedString("ok", value: "OK", comment: "OK button")
    static let notNow = NSLocalizedString("notnow", value: "Not Now", comment: "Not Now button")
    static let cancel = NSLocalizedString("cancel", value: "Cancel", comment: "Cancel button")
    static let submit = NSLocalizedString("submit", value: "Submit", comment: "Submit button")
    static let next = NSLocalizedString("next", value: "Next", comment: "Next button")
    static let copy = NSLocalizedString("copy", value: "Copy", comment: "Copy button")
    static let share = NSLocalizedString("share", value: "Share", comment: "Share button")
    static let pasteFromClipboard = NSLocalizedString("paste-from-clipboard", value: "Paste from Clipboard", comment: "Paste button")
    static let done = NSLocalizedString("done", value: "Done", comment: "Done button")

    static let sync = NSLocalizedString("preferences.sync", value: "Sync and Back Up", comment: "Show sync preferences")
    static let syncSetupExplanation = NSLocalizedString("preferences.sync.setup-explanation", value: "Securely sync and back up your bookmarks and Logins.", comment: "Sync setup explanation")

    static let syncAddDeviceCardExplanation = NSLocalizedString("preferences.sync.add-device-explanation", value: "To sync with another device, open the DuckDuckGo app on that device. Navigate to Settings > Sync & Back Up and scan the QR code below.", comment: "Sync add device explanation")
    static let syncAddDeviceCardActionsExplanation = NSLocalizedString("preferences.sync.add-device-actions-explanation", value: "Can't scan the QR code? Copy and paste the text code instead.", comment: "Sync add device actions explanation")
    static let syncAddDeviceShowTextActionTitle = NSLocalizedString("preferences.sync.add-device-show-text-action-title", value: "Show Text Code", comment: "Sync add device show text action title")
    static let syncAddDeviceEnterCodeActionTitle = NSLocalizedString("preferences.sync.add-device-enter-code-action-title", value: "Enter Text Code", comment: "Sync add device enter code action title")

    static let syncFirstDeviceSetUpCardTitle = NSLocalizedString("preferences.sync.first-device-setup-title", value: "Single-Device Setup", comment: "Sync first device setup title")
    static let syncFirstDeviceSetUpCardExplanation = NSLocalizedString("preferences.sync.first-device-setup-explanation", value: "Set up this device now, sync with other devices later.", comment: "Sync add device enter code action explanation")
    static let syncFirstDeviceSetUpActionTitle = NSLocalizedString("preferences.sync.first-device-setup-action-title", value: "Start Sync & Back Up", comment: "Sync first device setup action title")

    static let syncRecoverDataActionTitle = NSLocalizedString("preferences.sync.recover-data-action-title", value: "Recover Your Data", comment: "Sync recover data action title")

    static let syncSetUpFooter = NSLocalizedString("preferences.sync.setup-footer", value: "Your data is end-to-end encrypted, and DuckDuckGo does not have access to the decryption key.", comment: "Sync setup footer")

    static let turnOff = NSLocalizedString("preferences.sync.turn-off", value: "Turn Off", comment: "Turn off sync confirmation dialog button title")
    static let turnOffSync = NSLocalizedString("preferences.sync.turn-off.ellipsis", value: "Turn off Sync...", comment: "Disable sync button caption")
    static let turnOffSyncConfirmTitle = NSLocalizedString("preferences.sync.turn-off.confirm.title", value: "Turn Off Sync?", comment: "Turn off sync confirmation dialog title")
    static let turnOffSyncConfirmMessage = NSLocalizedString("preferences.sync.turn-off.confirm.message", value: "This device will no longer be able to access your synced data.", comment: "Turn off sync confirmation dialog message")
    static let turnOffAndDeleteServerData = NSLocalizedString("preferences.sync.turn-off-and-delete-data", value: "Turn Off and Delete Server Data", comment: "Disable and delete data sync button caption")
    static let syncConnected = NSLocalizedString("preferences.sync.connected", value: "Connected", comment: "Sync state")
    static let syncedDevices = NSLocalizedString("preferences.sync.synced-devices", value: "Synced Devices", comment: "Settings section title")
    static let syncNewDevice = NSLocalizedString("preferences.sync.sync-new-device", value: "Sync with Another Device", comment: "Settings section title")
    static let thisDevice = NSLocalizedString("preferences.sync.this-device", value: "This Device", comment: "Indicator of a current user's device on the list")
    static let currentDeviceDetails = NSLocalizedString("preferences.sync.current-device-details", value: "Details...", comment: "Sync Settings device details button")
    static let removeDeviceButton = NSLocalizedString("preferences.sync.remove-device", value: "Remove...", comment: "Button to remove a device")
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
    static let saveRecoveryPDF = NSLocalizedString("prefrences.sync.save-recovery-pdf", value: "Save Recovery PDF", comment: "Caption for a button to save Sync recovery PDF")

    static let showTextCodeTitle = NSLocalizedString("prefrences.sync.show-text-code-dialog-title", value: "Text Code", comment: "Title for show text code dialog")
    static let showTextCodeCaption = NSLocalizedString("prefrences.sync.show-text-code-dialog-caption", value: "Use this code after choosing \"Enter Text Code\" during sync setup on another device", comment: "Caption for show text code dialog")

    static let allSetDialogTitle = NSLocalizedString("prefrences.sync.all-set-dyalog-title", value: "All Set!", comment: "Title for all set dialog title")
    static let allSetDialogCaption = NSLocalizedString("prefrences.all-set-dyalog-caption", value: "You can sync this device’s bookmarks and Logins with additional devices at any time from the\n Sync & Back Up menu in Settings.", comment: "Caption for all set dialog")

    static let recoverSyncedDataTitle = NSLocalizedString("preferences.sync.recover-synced-data", value: "Enter Recovery Code", comment: "Recover Sync data dialog title")
    static let recoverSyncedDataExplanation = NSLocalizedString("preferences.sync.recover-synced-data-explanation", value: "Enter the code from your Recovery PDF.", comment: "Recover Sync data dialog content")
    static let manuallyEnterCodeTitle = NSLocalizedString("preferences.sync.manually-enter-code-title", value: "Enter Text Code", comment: "Sync manually enter codee dialog title")
    static let manuallyEnterCodeExplanation = NSLocalizedString("preferences.sync.manually-enter-code-explanation", value: "Enter the code found in Settings > Sync & Back Up > Show Text Code on another synced device, to sync this device.", comment: "Sync manually enter codee dialog content")

    static let deviceSynced = NSLocalizedString("prefrences.sync.device-synced", value: "Device Synced!", comment: "Sync setup dialog title")
    static let deviceSyncedExplanation = NSLocalizedString("prefrences.sync.device-synced-explanation", value: "Your bookmarks and Logins are now syncing with", comment: "Sync setup completion confirmation")
    static let multipleDeviceSyncedExplanation = NSLocalizedString("prefrences.sync.multiple-device-synced-explanation", value: "Your bookmarks and Logins are now syncing on", comment: "Sync setup completion confirmation")
    static let devicesWord = NSLocalizedString("prefrences.sync.multiple-device-synced-explanation-device word", value: "devices", comment: "Sync setup completion confirmation device word")

    static let recoveryPDFExplanation1 = NSLocalizedString("prefrences.sync.recovery-pdf-explanation1", value: "If you lose access to your devices, you will need this code to recover your synced data. You can save this code to your device as a PDF.", comment: "Sync recovery PDF explanation 2")
    static let recoveryPDFExplanation2 = NSLocalizedString("prefrences.sync.recovery-pdf-explanation2", value: "Anyone with access to this code can access your synced data, so please keep it in a safe place.", comment: "Sync recovery PDF explanation")

    static let deviceDetailsTitle = NSLocalizedString("prefrences.sync.device-details.title", value: "Device Details", comment: "The title of the device details dialog")
    static let deviceDetailsLabel = NSLocalizedString("prefrences.sync.device-details.label", value: "Name", comment: "The text entry label")
    static let deviceDetailsPrompt = NSLocalizedString("prefrences.sync.device-details.prompt", value: "Device name", comment: "The text entry prompt")

    static let deleteAccountTitle = NSLocalizedString("prefrences.sync.delete-account.title", value: "Delete Server Data?", comment: "Title for delete account")
    static let deleteAccountMessage = NSLocalizedString("prefrences.sync.delete-account.message", value: "These devices will be disconnected and your synced data will be deleted from the server.", comment: "Message for delete account")
    static let deleteAccountButton = NSLocalizedString("prefrences.sync.delete-account.button", value: "Delete Data", comment: "Label for delete account button")

    static let optionsSectionDialogTitle = NSLocalizedString("prefrences.sync.options-section-dialog-title", value: "Options", comment: "Title for options settings in dialog")
    static let optionsSectionTitle = NSLocalizedString("prefrences.sync.options-section-title", value: "Settings", comment: "Title for options settings")
    static let fetchFaviconsOptionTitle = NSLocalizedString("prefrences.sync.fetch-favicons-option-title", value: "Fetch Bookmark Icons", comment: "Title for fetch favicons option")
    static let fetchFaviconsOptionCaption = NSLocalizedString("prefrences.sync.fetch-favicons-option-caption", value: "Automatically download icons for synced bookmarks.", comment: "Caption for fetch favicons option")

    static let shareFavoritesOptionTitle = NSLocalizedString("prefrences.sync.share-favorite-option-title", value: "Share Favorites", comment: "Title for share favorite option")
    static let shareFavoritesOptionCaption = NSLocalizedString("prefrences.sync.share-favorite-option-caption", value: "Use the same favorites on all devices. Leave off to keep mobile and desktop favorites separate.", comment: "Caption for share favorite option")

    static let syncLimitExceededTitle = NSLocalizedString("prefrences.sync.limit-exceeded-title", value: "Sync Paused", comment: "Title for sync limits exceeded warning")
    static let bookmarksLimitExceededDescription = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-description", value: "Bookmark limit exceeded. Delete some to resume syncing.", comment: "Description for sync bookmarks limits exceeded warning")
    static let credentialsLimitExceededDescription = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-description", value: "Logins limit exceeded. Delete some to resume syncing.", comment: "Description for sync credentials limits exceeded warning")
    static let bookmarksLimitExceededAction = NSLocalizedString("prefrences.sync.bookmarks-limit-exceeded-action", value: "Manage Bookmarks", comment: "Button title for sync bookmarks limits exceeded warning to manage bookmarks")
    static let credentialsLimitExceededAction = NSLocalizedString("prefrences.sync.credentials-limit-exceeded-action", value: "Manage Logins", comment: "Button title for sync credentials limits exceeded warning to manage logins")

    static let fetchFaviconsOnboardingTitle = NSLocalizedString("prefrences.sync.fetch-favicons-onboarding-title", value: "Download Missing Icons?", comment: "Title for fetch favicons onboarding dialog")
    static let fetchFaviconsOnboardingMessage = NSLocalizedString("prefrences.sync.fetch-favicons-onboarding-message", value: "Do you want this device to automatically download icons for any new bookmarks synced from your other devices? This will expose the download to your network any time a bookmark is synced.", comment: "Text for fetch favicons onboarding dialog")
    static let keepFaviconsUpdated = NSLocalizedString("prefrences.sync.keep-favicons-updated", value: "Keep Bookmarks Icons Updated", comment: "Title of the confirmation button for favicons fetching")
}
