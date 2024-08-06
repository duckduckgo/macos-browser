//
//  VPNUIActionHandler.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import AppLauncher
import Foundation
import NetworkProtectionProxy
import NetworkProtectionUI
import VPNAppLauncher

/// VPN Agent's UI action handler
///
final class VPNUIActionHandler: VPNUIActionHandling {

    private let appLauncher: AppLauncher
    private let proxySettings: TransparentProxySettings

    init(appLauncher: AppLauncher, proxySettings: TransparentProxySettings) {
        self.appLauncher = appLauncher
        self.proxySettings = proxySettings
    }

    public func moveAppToApplications() async {
#if !APPSTORE && !DEBUG
        try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.moveAppToApplications)
#endif
    }

    func setExclusion(_ exclude: Bool, forDomain domain: String) async {
        proxySettings.setExclusion(exclude, forDomain: domain)
    }

    public func shareFeedback() async {
        try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
    }

    public func showVPNLocations() async {
        try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showVPNLocations)
    }

    public func showPrivacyPro() async {
        try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showPrivacyPro)
    }
}
