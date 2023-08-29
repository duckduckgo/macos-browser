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

    @IBOutlet weak var useRemoteValueMenuItem: NSMenuItem!
    @IBOutlet weak var overrideONMenuItem: NSMenuItem!
    @IBOutlet weak var overrideOFFMenuItem: NSMenuItem!

    @UserDefaultsWrapper(key: .networkProtectionWaitlistBetaActiveOverrideRawValue,
                         defaultValue: WaitlistBetaActive.default.rawValue,
                         defaults: .shared)
    private var overrideValue: Int

    @IBAction
    func waitlistBetaActiveUseRemoteValue(sender: NSMenuItem) {
        overrideValue = WaitlistBetaActive.useRemoteValue.rawValue
    }

    @IBAction
    func waitlistBetaActiveOverrideON(sender: NSMenuItem) {
        overrideValue = WaitlistBetaActive.on.rawValue
    }

    @IBAction
    func waitlistBetaActiveOverrideOFF(sender: NSMenuItem) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await betaActiveOFFAlert().runModal() else {
                return
            }

            overrideValue = WaitlistBetaActive.off.rawValue
        }
    }

    override func update() {
        useRemoteValueMenuItem.state = overrideValue == WaitlistBetaActive.useRemoteValue.rawValue ? .on : .off
        overrideONMenuItem.state = overrideValue == WaitlistBetaActive.on.rawValue ? .on : .off
        overrideOFFMenuItem.state = overrideValue == WaitlistBetaActive.off.rawValue ? .on : .off
    }

    // MARK: - UI Additions

    private func betaActiveOFFAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Override waitlistBetaActive to OFF value?"
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
