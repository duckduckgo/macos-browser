//
//  NSAlertExtension.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Cocoa

extension NSAlert {

    static func fireproofAlert(with domain: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.fireproofConfirmationTitle(domain: domain)
        alert.informativeText = UserText.fireproofConfirmationMessage
        alert.alertStyle = .warning
        alert.icon = .fireproof
        alert.addButton(withTitle: UserText.fireproof)
        alert.addButton(withTitle: UserText.notNow)
        return alert
    }

    static func clearAllHistoryAndDataAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.clearAllDataQuestion
        alert.informativeText = UserText.clearAllDataDescription
        alert.alertStyle = .warning
        alert.icon = .burnAlert
        alert.addButton(withTitle: UserText.clear)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func clearHistoryAndDataAlert(dateString: String?) -> NSAlert {
        let alert = NSAlert()
        if let dateString = dateString {
            alert.messageText = String(format: UserText.clearDataHeader, dateString)
            alert.informativeText = UserText.clearDataDescription
        } else {
            alert.messageText = String(format: UserText.clearDataTodayHeader)
            alert.informativeText = UserText.clearDataTodayDescription
        }
        alert.alertStyle = .warning
        alert.icon = .burnAlert
        alert.addButton(withTitle: UserText.clear)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func exportLoginsFailed() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.exportLoginsFailedMessage
        alert.informativeText = UserText.exportLoginsFailedInformative
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func exportBookmarksFailed() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.exportBookmarksFailedMessage
        alert.informativeText = UserText.exportBookmarksFailedInformative
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func databaseFactoryFailed() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.databaseFactoryFailedMessage
        alert.informativeText = UserText.databaseFactoryFailedInformative
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func resetNetworkProtectionAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Reset VPN?"
        alert.informativeText = """
        This will remove your stored network configuration (including private key) and disable the VPN.

        You can re-enable the VPN from the status view.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func removeSystemExtensionAndAgentsAlert() -> NSAlert {
        let alert = NSAlert()
#if NETP_SYSTEM_EXTENSION
        let sysExText = "System Extension and "
#else
        let sysExText = ""
#endif
        alert.messageText = "Uninstall \(sysExText)Login Items?"
        alert.informativeText = "This will remove the VPN \(sysExText)Status Menu icon and disable the VPN."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func removeAllDBPStateAndDataAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Uninstall Personal Information Removal Login Item?"
        alert.informativeText = "This will remove the Personal Information Removal Login Item, delete all your data and reset the waitlist state."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func noAccessToDownloads() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.noAccessToDownloadsFolderHeader
        alert.informativeText = UserText.noAccessToDownloadsFolder
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.openSystemPreferences)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func noAccessToSelectedFolder() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.noAccessToSelectedFolderHeader
        alert.informativeText = UserText.noAccessToSelectedFolder
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func disableEmailProtection() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.disableEmailProtectionTitle
        alert.informativeText = UserText.disableEmailProtectionMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.disable)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func cannotOpenFileAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.cannotOpenFileAlertHeader
        alert.informativeText = UserText.cannotOpenFileAlertInformative
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.learnMore)
        return alert
    }

    static func osNotSupported() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.aboutUnsupportedDeviceInfo1
        alert.informativeText = UserText.aboutUnsupportedDeviceInfo2(version: "\(SupportedOSChecker.SupportedVersion.major).\(SupportedOSChecker.SupportedVersion.minor)")
        alert.alertStyle = .warning

        alert.addButton(withTitle: UserText.checkForUpdate)
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func syncBookmarksPaused() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.syncBookmarkPausedAlertTitle
        alert.informativeText = UserText.syncBookmarkPausedAlertDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.learnMore)
        return alert
    }

    static func syncCredentialsPaused() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.syncCredentialsPausedAlertTitle
        alert.informativeText = UserText.syncCredentialsPausedAlertDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.learnMore)
        return alert
    }

    static func dataSyncingDisabledByFeatureFlag(showLearnMore: Bool, upgradeRequired: Bool = false) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.syncPausedTitle
        alert.informativeText = upgradeRequired ? UserText.syncUnavailableMessageUpgradeRequired : UserText.syncUnavailableMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        if showLearnMore {
            alert.addButton(withTitle: UserText.learnMore)
        }
        return alert
    }

    static func customConfigurationAlert(configurationUrl: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Set custom configuration URL:"
        alert.addButton(withTitle: UserText.ok)
        alert.addButton(withTitle: UserText.cancel)
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.maximumNumberOfLines = 1
        textField.lineBreakMode = .byTruncatingTail
        textField.stringValue = configurationUrl
        alert.accessoryView = textField
        alert.window.initialFirstResponder = alert.accessoryView
        textField.currentEditor()?.selectAll(nil)
        return alert
    }

    @discardableResult
    func runModal() async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            continuation.resume(returning: self.runModal())
        }
    }
}
