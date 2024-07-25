//
//  VPNURLEventHandler.swift
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

import Foundation
import PixelKit
import VPNAppLauncher

@MainActor
final class VPNURLEventHandler {

    private let windowControllerManager: WindowControllersManager

    init(windowControllerManager: WindowControllersManager? = nil) {
        self.windowControllerManager = windowControllerManager ?? .shared
    }

    /// Handles VPN event URLs
    ///
    func handle(_ url: URL) async {
        switch url {
        case VPNAppLaunchCommand.showStatus.launchURL:
            await showStatus()
        case VPNAppLaunchCommand.showSettings.launchURL:
            showPreferences()
        case VPNAppLaunchCommand.shareFeedback.launchURL:
            showShareFeedback()
        case VPNAppLaunchCommand.justOpen.launchURL:
            showMainWindow()
        case VPNAppLaunchCommand.showVPNLocations.launchURL:
            showLocations()
        case VPNAppLaunchCommand.showPrivacyPro.launchURL:
            showPrivacyPro()
#if !APPSTORE && !DEBUG
        case VPNAppLaunchCommand.moveAppToApplications.launchURL:
            moveAppToApplicationsFolder()
#endif
        default:
            return
        }
    }

    func showStatus() async {
        await windowControllerManager.showNetworkProtectionStatus()
    }

    func showPreferences() {
        windowControllerManager.showPreferencesTab(withSelectedPane: .vpn)
    }

    func showShareFeedback() {
        windowControllerManager.showShareFeedbackModal()
    }

    func showMainWindow() {
        windowControllerManager.showMainWindow()
    }

    func showLocations() {
        windowControllerManager.showPreferencesTab(withSelectedPane: .vpn)
        windowControllerManager.showLocationPickerSheet()
    }

    func showPrivacyPro() {
        let url = Application.appDelegate.subscriptionManager.url(for: .purchase)
        windowControllerManager.showTab(with: .subscription(url))

        PixelKit.fire(PrivacyProPixel.privacyProOfferScreenImpression)
    }

    func moveAppToApplicationsFolder() {
        // this should be run after NSApplication.shared is set
        PFMoveToApplicationsFolderIfNecessary(false)
    }
}
