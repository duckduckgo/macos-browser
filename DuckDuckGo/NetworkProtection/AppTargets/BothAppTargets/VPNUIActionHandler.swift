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
import NetworkProtectionIPC
import NetworkProtectionProxy
import NetworkProtectionUI
import VPNAppLauncher

/// Main App's VPN UI action handler
///
final class VPNUIActionHandler {

    private let vpnIPCClient: VPNControllerXPCClient
    private let proxySettings: TransparentProxySettings
    private let vpnURLEventHandler: VPNURLEventHandler

    init(vpnIPCClient: VPNControllerXPCClient = .shared,
         vpnURLEventHandler: VPNURLEventHandler,
         proxySettings: TransparentProxySettings) {

        self.vpnIPCClient = vpnIPCClient
        self.vpnURLEventHandler = vpnURLEventHandler
        self.proxySettings = proxySettings
    }

    func askUserToReportIssues(withDomain domain: String) async {
        let parentWindow = await WindowControllersManager.shared.lastKeyMainWindowController?.window
        await ReportSiteIssuesPresenter(userDefaults: .netP).show(withDomain: domain, in: parentWindow)
    }
}

extension VPNUIActionHandler: VPNUIActionHandling {

    func moveAppToApplications() async {
#if !APPSTORE && !DEBUG
        await vpnURLEventHandler.moveAppToApplicationsFolder()
#endif
    }

    func setExclusion(_ exclude: Bool, forDomain domain: String) async {
        proxySettings.setExclusion(exclude, forDomain: domain)
        try? await vpnIPCClient.command(.restartAdapter)

        if exclude {
            await askUserToReportIssues(withDomain: domain)
        }

        await vpnURLEventHandler.reloadTab(showingDomain: domain)
    }

    func shareFeedback() async {
        await vpnURLEventHandler.showShareFeedback()
    }

    func showVPNLocations() async {
        await vpnURLEventHandler.showLocations()
    }

    func showPrivacyPro() async {
        await vpnURLEventHandler.showPrivacyPro()
    }
}
