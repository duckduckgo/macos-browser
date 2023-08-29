//
//  NetworkProtectionWaitlistMenu.swift
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

import AppKit
import Foundation

#if !NETWORK_PROTECTION

@objc
final class NetworkProtectionWaitlistMenu: NSMenu {
}

#else

import NetworkProtection
import NetworkProtectionUI

/// Implements the logic for Network Protection's simulate failures menu.
///
@available(macOS 11.4, *)
@objc
@MainActor
final class NetworkProtectionWaitlistMenu: NSMenu {

    // MARK: - Waitlist Active Properties

    @IBOutlet weak var waitlistActiveUseRemoteValueMenuItem: NSMenuItem!
    @IBOutlet weak var waitlistActiveOverrideONMenuItem: NSMenuItem!
    @IBOutlet weak var waitlistActiveOverrideOFFMenuItem: NSMenuItem!

    @UserDefaultsWrapper(key: .networkProtectionWaitlistActiveOverrideRawValue,
                         defaultValue: WaitlistOverride.default.rawValue,
                         defaults: .shared)
    private var waitlistActiveOverrideValue: Int

    // MARK: - Waitlist Enabled Properties

    @IBOutlet weak var waitlistEnabledUseRemoteValueMenuItem: NSMenuItem!
    @IBOutlet weak var waitlistEnabledOverrideONMenuItem: NSMenuItem!
    @IBOutlet weak var waitlistEnabledOverrideOFFMenuItem: NSMenuItem!

    @UserDefaultsWrapper(key: .networkProtectionWaitlistEnabledOverrideRawValue,
                         defaultValue: WaitlistOverride.default.rawValue,
                         defaults: .shared)
    private var waitlistEnabledOverrideValue: Int

    // MARK: - Waitlist Active IBActions

    @IBAction
    func waitlistActiveUseRemoteValue(sender: NSMenuItem) {
        waitlistActiveOverrideValue = WaitlistOverride.useRemoteValue.rawValue
    }

    @IBAction
    func waitlistActiveOverrideON(sender: NSMenuItem) {
        waitlistActiveOverrideValue = WaitlistOverride.on.rawValue
    }

    @IBAction
    func waitlistActiveOverrideOFF(sender: NSMenuItem) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await waitlistOFFAlert().runModal() else {
                return
            }

            waitlistActiveOverrideValue = WaitlistOverride.off.rawValue
        }
    }

    // MARK: - Waitlist Enabled IBActions

    @IBAction
    func waitlistEnabledUseRemoteValue(sender: NSMenuItem) {
        waitlistEnabledOverrideValue = WaitlistOverride.useRemoteValue.rawValue
    }

    @IBAction
    func waitlistEnabledOverrideON(sender: NSMenuItem) {
        waitlistEnabledOverrideValue = WaitlistOverride.on.rawValue
    }

    @IBAction
    func waitlistEnabledOverrideOFF(sender: NSMenuItem) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await waitlistOFFAlert().runModal() else {
                return
            }

            waitlistEnabledOverrideValue = WaitlistOverride.off.rawValue
        }
    }

    // MARK: - Updating the menu state

    override func update() {
        waitlistActiveUseRemoteValueMenuItem.state = waitlistActiveOverrideValue == WaitlistOverride.useRemoteValue.rawValue ? .on : .off
        waitlistActiveOverrideONMenuItem.state = waitlistActiveOverrideValue == WaitlistOverride.on.rawValue ? .on : .off
        waitlistActiveOverrideOFFMenuItem.state = waitlistActiveOverrideValue == WaitlistOverride.off.rawValue ? .on : .off

        waitlistEnabledUseRemoteValueMenuItem.state = waitlistEnabledOverrideValue == WaitlistOverride.useRemoteValue.rawValue ? .on : .off
        waitlistEnabledOverrideONMenuItem.state = waitlistEnabledOverrideValue == WaitlistOverride.on.rawValue ? .on : .off
        waitlistEnabledOverrideOFFMenuItem.state = waitlistEnabledOverrideValue == WaitlistOverride.off.rawValue ? .on : .off
    }

    // MARK: - UI Additions

    private func waitlistOFFAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Override to OFF value?"
        alert.informativeText = """
        This will potentially disable Network Protection and erase your invitation.

        You can re-enable Network Protection after reverting this change.

        Please click 'Cancel' if you're unsure.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Override")
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }
}

#endif
