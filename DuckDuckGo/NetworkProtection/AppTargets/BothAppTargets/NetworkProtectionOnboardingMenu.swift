//
//  NetworkProtectionOnboardingMenu.swift
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
import NetworkProtection
import NetworkProtectionUI
import SwiftUI

/// Implements the logic for the VPN's onboarding menu.
///
final class NetworkProtectionOnboardingMenu: NSMenu {

    private let resetMenuItem = NSMenuItem(title: "Reset Onboarding Status",
                                           action: #selector(NetworkProtectionOnboardingMenu.reset))
    private let setStatusCompletedMenuItem = NSMenuItem(title: "Onboarding Completed",
                                                        action: #selector(NetworkProtectionOnboardingMenu.setStatusCompleted))
    private let setStatusAllowSystemExtensionMenuItem = NSMenuItem(title: "Install VPN System Extension",
                                                                   action: #selector(NetworkProtectionOnboardingMenu.setStatusAllowSystemExtension))
    private let setStatusAllowVPNConfigurationMenuItem = NSMenuItem(title: "Allow VPN Configuration",
                                                                    action: #selector(NetworkProtectionOnboardingMenu.setStatusAllowVPNConfiguration))

    @UserDefaultsWrapper(key: .networkProtectionOnboardingStatusRawValue, defaultValue: OnboardingStatus.default.rawValue, defaults: .netP)
    var onboardingStatus: OnboardingStatus.RawValue

    init() {
        super.init(title: "")

        buildItems {
            resetMenuItem.targetting(self)
            NSMenuItem.separator()
            NSMenuItem(title: "Set Status") {
                setStatusCompletedMenuItem.targetting(self)
                setStatusAllowSystemExtensionMenuItem.targetting(self)
                setStatusAllowVPNConfigurationMenuItem.targetting(self)
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func reset(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.default.rawValue
    }

    @objc func setStatusCompleted(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.completed.rawValue
    }

    @objc func setStatusAllowSystemExtension(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.isOnboarding(step: .userNeedsToAllowExtension).rawValue
    }

    @objc func setStatusAllowVPNConfiguration(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.isOnboarding(step: .userNeedsToAllowVPNConfiguration).rawValue
    }
}

#if DEBUG
#Preview {
    return MenuPreview(menu: NetworkProtectionOnboardingMenu())
}
#endif
