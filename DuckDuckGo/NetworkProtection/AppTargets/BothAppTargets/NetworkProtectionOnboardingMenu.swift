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

#if !NETWORK_PROTECTION

@objc
final class NetworkProtectionOnboardingMenu: NSMenu {
}

#else

import NetworkProtection
import NetworkProtectionUI

/// Implements the logic for Network Protection's simulate failures menu.
///
@available(macOS 11.4, *)
@objc
@MainActor
final class NetworkProtectionOnboardingMenu: NSMenu {
    @IBOutlet weak var resetMenuItem: NSMenuItem!
    @IBOutlet weak var setStatusCompletedMenuItem: NSMenuItem!
    @IBOutlet weak var setStatusAllowSystemExtensionMenuItem: NSMenuItem!
    @IBOutlet weak var setStatusAllowVPNConfigurationMenuItem: NSMenuItem!

    @UserDefaultsWrapper(key: .networkProtectionOnboardingStatusRawValue, defaultValue: OnboardingStatus.default.rawValue, defaults: .shared)
    var onboardingStatus: OnboardingStatus.RawValue

    @IBAction
    func reset(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.default.rawValue
    }

    @IBAction
    func setStatusCompleted(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.completed.rawValue
    }

    @IBAction
    func setStatusAllowSystemExtension(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.isOnboarding(step: .userNeedsToAllowExtension).rawValue
    }

    @IBAction
    func setStatusAllowVPNConfiguration(sender: NSMenuItem) {
        onboardingStatus = OnboardingStatus.isOnboarding(step: .userNeedsToAllowVPNConfiguration).rawValue
    }
}

#endif
