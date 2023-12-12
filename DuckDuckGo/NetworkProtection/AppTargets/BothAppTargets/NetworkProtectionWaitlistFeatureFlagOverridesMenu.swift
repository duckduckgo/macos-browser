//
//  NetworkProtectionWaitlistFeatureFlagOverridesMenu.swift
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

#if NETWORK_PROTECTION

import AppKit
import Foundation
import NetworkProtection
import NetworkProtectionUI
import SwiftUI

/// Implements the logic for Network Protection's simulate failures menu.
///
@MainActor
final class NetworkProtectionWaitlistFeatureFlagOverridesMenu: NSMenu {

    // MARK: - Waitlist Active Properties

    private let waitlistActiveUseRemoteValueMenuItem: NSMenuItem
    private let waitlistActiveOverrideONMenuItem: NSMenuItem
    private let waitlistActiveOverrideOFFMenuItem: NSMenuItem

    @UserDefaultsWrapper(key: .networkProtectionWaitlistActiveOverrideRawValue,
                         defaultValue: WaitlistOverride.default.rawValue,
                         defaults: .netP)
    private var waitlistActiveOverrideValue: Int

    // MARK: - Waitlist Enabled Properties

    private let waitlistEnabledUseRemoteValueMenuItem: NSMenuItem
    private let waitlistEnabledOverrideONMenuItem: NSMenuItem
    private let waitlistEnabledOverrideOFFMenuItem: NSMenuItem

    @UserDefaultsWrapper(key: .networkProtectionWaitlistEnabledOverrideRawValue,
                         defaultValue: WaitlistOverride.default.rawValue,
                         defaults: .netP)
    private var waitlistEnabledOverrideValue: Int

    init() {
        waitlistActiveUseRemoteValueMenuItem = NSMenuItem(title: "Remote Value", action: #selector(Self.waitlistEnabledUseRemoteValue))
        waitlistActiveOverrideONMenuItem = NSMenuItem(title: "ON", action: #selector(Self.waitlistEnabledOverrideON))
        waitlistActiveOverrideOFFMenuItem = NSMenuItem(title: "OFF", action: #selector(Self.waitlistEnabledOverrideOFF))

        waitlistEnabledUseRemoteValueMenuItem = NSMenuItem(title: "Remote Value", action: #selector(Self.waitlistActiveUseRemoteValue))
        waitlistEnabledOverrideONMenuItem = NSMenuItem(title: "ON", action: #selector(Self.waitlistActiveOverrideON))
        waitlistEnabledOverrideOFFMenuItem = NSMenuItem(title: "OFF", action: #selector(Self.waitlistActiveOverrideOFF))

        super.init(title: "")
        buildItems {
            NSMenuItem(title: "Reset Waitlist Overrides", action: #selector(Self.waitlistResetFeatureOverrides)).targetting(self)
            NSMenuItem.separator()

            NSMenuItem(title: "Waitlist Enabled") {
                waitlistActiveUseRemoteValueMenuItem.targetting(self)
                waitlistActiveOverrideONMenuItem.targetting(self)
                waitlistActiveOverrideOFFMenuItem.targetting(self)
            }

            NSMenuItem(title: "Waitlist Active") {
                waitlistEnabledUseRemoteValueMenuItem.targetting(self)
                waitlistEnabledOverrideONMenuItem.targetting(self)
                waitlistEnabledOverrideOFFMenuItem.targetting(self)
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Misc IBActions

    @objc func waitlistResetFeatureOverrides(sender: NSMenuItem) {
        waitlistActiveOverrideValue = WaitlistOverride.default.rawValue
        waitlistEnabledOverrideValue = WaitlistOverride.default.rawValue
    }

    // MARK: - Waitlist Active IBActions

    @objc func waitlistActiveUseRemoteValue(sender: NSMenuItem) {
        waitlistActiveOverrideValue = WaitlistOverride.useRemoteValue.rawValue
    }

    @objc func waitlistActiveOverrideON(sender: NSMenuItem) {
        waitlistActiveOverrideValue = WaitlistOverride.on.rawValue
    }

    @objc func waitlistActiveOverrideOFF(sender: NSMenuItem) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await waitlistOFFAlert().runModal() else {
                return
            }

            waitlistActiveOverrideValue = WaitlistOverride.off.rawValue
        }
    }

    // MARK: - Waitlist Enabled IBActions

    @objc func waitlistEnabledUseRemoteValue(sender: NSMenuItem) {
        waitlistEnabledOverrideValue = WaitlistOverride.useRemoteValue.rawValue
    }

    @objc func waitlistEnabledOverrideON(sender: NSMenuItem) {
        waitlistEnabledOverrideValue = WaitlistOverride.on.rawValue
    }

    @objc func waitlistEnabledOverrideOFF(sender: NSMenuItem) {
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

#if DEBUG
#Preview {
    return MenuPreview(menu: NetworkProtectionWaitlistFeatureFlagOverridesMenu())
}
#endif

#endif
