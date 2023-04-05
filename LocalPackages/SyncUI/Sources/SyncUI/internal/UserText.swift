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
    static let pasteFromClipboard = NSLocalizedString("paste-from-clipboard", value: "Paste from Clipboard", comment: "Paste button")

    static let sync = NSLocalizedString("preferences.sync", value: "Sync", comment: "Show sync preferences")

    static let syncSetupExplanation = NSLocalizedString("preferences.sync.setup-explanation", value: "Sync your bookmarks across your devices and save an encrypted backup on DuckDuckGo’s servers.", comment: "Sync setup explanation")
    static let turnOnSync = NSLocalizedString("preferences.sync.turn-on", value: "Turn on Sync", comment: "Enable sync button caption")
    static let turnOnSyncWithEllipsis = NSLocalizedString("preferences.sync.turn-on-ellipsis", value: "Turn on Sync...", comment: "Enable sync button caption")
    static let turnOffSync = NSLocalizedString("preferences.sync.turn-off", value: "Turn off Sync...", comment: "Disable sync button caption")
    static let turnOffAndDeleteServerData = NSLocalizedString("preferences.sync.turn-off-and-delete-data", value: "Turn Off and Delete Server Data", comment: "Disable and delete data sync button caption")
    static let recoverSyncedData = NSLocalizedString("preferences.sync.recover", value: "Recover synced data with backup code", comment: "Caption for a button to recover synced data")
    static let syncConnected = NSLocalizedString("preferences.sync.connected", value: "Connected", comment: "Sync state")
    static let syncedDevices = NSLocalizedString("preferences.sync.synced-devices", value: "Synced Devices", comment: "Settings section title")
    static let syncNewDevice = NSLocalizedString("preferences.sync.sync-new-device", value: "Sync New Device", comment: "Settings section title")
    static let thisDevice = NSLocalizedString("preferences.sync.this-device", value: "This Device", comment: "Indicator of a current user's device on the list")
    static let currentDeviceDetails = NSLocalizedString("preferences.sync.current-device-details", value: "Details...", comment: "Sync Settings device details button")
    static let syncNewDeviceInstructions = NSLocalizedString("prefrences.sync.sync-new-device-instructions", value: "Go to Settings > Sync in the DuckDuckGo App on a different device and scan the image on the left to connect instantly.", comment: "Instructions for adding a new device to sync")
    static let showOrEnterCode = NSLocalizedString("prefrences.sync.show-or-enter-code", value: "Show or Enter Code", comment: "Button caption in Sync's add new device screen")
    static let recovery = NSLocalizedString("prefrences.sync.recovery", value: "Recovery", comment: "Sync settings section title")
    static let recoveryInstructions = NSLocalizedString("prefrences.sync.recovery-instructions", value: "If you lose your device, you will need this recovery code to restore your synced data.", comment: "Instructions on how to restore synced data")
    static let saveRecoveryPDF = NSLocalizedString("prefrences.sync.save-recovery-pdf", value: "Save Recovery PDF", comment: "Caption for a button to save Sync recovery PDF")

    static let turnOnSyncQuestion = NSLocalizedString("preferences.sync.turn-on-question", value: "Turn on Sync?", comment: "Sync setup dialog title")
    static let turnOnSyncExplanation1 = NSLocalizedString("preferences.sync.turn-on-explanation1", value: "This will save an encrypted backup of your bookmarks on DuckDuckGo’s servers, which can be synced with your other devices.", comment: "Sync setup dialog content")
    static let turnOnSyncExplanation2 = NSLocalizedString("preferences.sync.turn-on-explanation2", value: "The decryption key is stored on your device and cannot be read by DuckDuckGo.", comment: "Sync setup dialog content")

    static let recoverSyncedDataTitle = NSLocalizedString("preferences.sync.recover-synced-data", value: "Recover Synced Data", comment: "Sync setup dialog title")
    static let recoverSyncedDataExplanation = NSLocalizedString("preferences.sync.recover-synced-data-explanation", value: "Enter the code on your recovery PDF or another synced device below to recover your synced data.", comment: "Sync setup dialog content")

    static let syncAnotherDeviceTitle = NSLocalizedString("preferences.sync.sync-another-device-question", value: "Sync Another Device?", comment: "Sync setup dialog title")
    static let syncAnotherDeviceExplanation1 = NSLocalizedString("preferences.sync.sync-another-device-explanation1", value: "Your bookmarks will be backed up! Would you like to sync with another device now?", comment: "Sync setup dialog content")
    static let syncAnotherDeviceExplanation2 = NSLocalizedString("preferences.sync.sync-another-device-explanation2", value: "If you’ve already set up Sync on another device, this will allow you to combine bookmarks from both devices into a single backup.", comment: "Sync setup dialog content")
    static let syncAnotherDevice = NSLocalizedString("preferences.sync.sync-another-device", value: "Sync Another Device", comment: "Button caption")

    static let showCode = NSLocalizedString("prefrences.sync.show-code", value: "Show Code", comment: "Button caption in Sync's add new device screen")
    static let enterCode = NSLocalizedString("prefrences.sync.enter-code", value: "Enter Code", comment: "Button caption in Sync's add new device screen")
    static let syncNewDeviceShowCodeInstructions = NSLocalizedString("prefrences.sync.sync-new-device-show-code-instructions", value: "Go to Settings > Sync in the DuckDuckGo App on a different device and select Scan or Manually Enter Code to sync.", comment: "Instructions for adding a new device to sync")
    static let syncNewDeviceEnterCodeInstructions = NSLocalizedString("prefrences.sync.sync-new-device-enter-code-instructions", value: "Enter the code on your Recovery PDF, or another synced device below to recover your synced data.", comment: "Instructions for adding a new device to sync")

    static let deviceSynced = NSLocalizedString("prefrences.sync.device-synced", value: "Device Synced!", comment: "Sync setup dialog title")
    static let deviceSyncedExplanation = NSLocalizedString("prefrences.sync.device-synced-explanation", value: "Your bookmarks are now syncing with this device.", comment: "Sync setup completion confirmation")

    static let recoveryPDFExplanation1 = NSLocalizedString("prefrences.sync.recovery-pdf-explanation1", value: "If you lose access to your devices, you will need the code recover your synced data. You can save this code to your device as a PDF.", comment: "Sync recovery PDF explanation")
    static let recoveryPDFExplanation2 = NSLocalizedString("prefrences.sync.recovery-pdf-explanation2", value: "Anyone with access to this code can access your synced data, so please keep it in a safe place.", comment: "Sync recovery PDF explanation")

}
