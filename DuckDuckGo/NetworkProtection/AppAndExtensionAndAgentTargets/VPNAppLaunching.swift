//
<<<<<<<< HEAD:DuckDuckGo/NetworkProtection/AppAndExtensionAndAgentTargets/VPNAppLaunching.swift
//  VPNAppLaunching.swift
========
//  AppLauncher+VPNUIActionHandler.swift
>>>>>>>> diego/app-launcher-code-cleanup:DuckDuckGo/NetworkProtection/AppAndExtensionAndAgentTargets/AppLauncher+VPNUIActionHandler.swift
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
import NetworkProtectionUI

<<<<<<<< HEAD:DuckDuckGo/NetworkProtection/AppAndExtensionAndAgentTargets/VPNAppLaunching.swift
public enum VPNAppLaunchCommand: Codable {
    case justOpen
    case shareFeedback
    case showFAQ
    case showStatus
    case showSettings
    case showVPNLocations
    case startVPN
    case stopVPN
    case enableOnDemand
    case moveAppToApplications
    case showPrivacyPro
}

public protocol VPNAppLaunching {
    func launchApp(withCommand command: VPNAppLaunchCommand) async
========
extension AppLauncher: VPNUIActionHandler {
    public func showVPNLocations() async {
        try? await launchApp(withCommand: .showVPNLocations)
    }

    public func moveAppToApplications() async {
        try? await launchApp(withCommand: .moveAppToApplications)
    }

    public func showPrivacyPro() async {
        try? await launchApp(withCommand: .showPrivacyPro)
    }
>>>>>>>> diego/app-launcher-code-cleanup:DuckDuckGo/NetworkProtection/AppAndExtensionAndAgentTargets/AppLauncher+VPNUIActionHandler.swift
}
