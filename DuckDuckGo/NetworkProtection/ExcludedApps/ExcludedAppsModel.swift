//
//  ExcludedAppsModel.swift
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

import AppInfoRetriever
import Foundation
import NetworkProtectionIPC
import NetworkProtectionProxy
import NetworkProtectionUI
import PixelKit

protocol ExcludedAppsModel {
    var excludedApps: [String] { get }
    func getAppInfo(bundleID: String) -> AppInfo

    func add(appURL: URL) -> AppInfo?
    func remove(bundleID: String)
}

final class DefaultExcludedAppsModel {
    private let appInfoRetriever: AppInfoRetrieving = AppInfoRetriever()
    let proxySettings = TransparentProxySettings(defaults: .netP)
    private let pixelKit: PixelFiring?
    private let vpnXPCClient: VPNControllerXPCClient

    init(vpnXPCClient: VPNControllerXPCClient = VPNControllerXPCClient.shared, pixelKit: PixelFiring? = PixelKit.shared) {
        self.pixelKit = pixelKit
        self.vpnXPCClient = vpnXPCClient
    }
}

extension DefaultExcludedAppsModel: ExcludedAppsModel {

    var excludedApps: [String] {
        proxySettings.excludedApps
    }

    func add(appURL: URL) -> AppInfo? {
        guard let appInfo = appInfoRetriever.getAppInfo(appURL: appURL) else {
            return nil
        }

        proxySettings.appRoutingRules[appInfo.bundleID] = .exclude
        reloadVPN()
        return appInfo
    }

    func remove(bundleID: String) {
        guard proxySettings.appRoutingRules[bundleID] == .exclude else {
            return
        }

        proxySettings.appRoutingRules.removeValue(forKey: bundleID)
        reloadVPN()
    }

    /// Provides AppInfo for the specified bundleID for the scope of presenting the information to the user.
    ///
    /// Since this method is specific to show app information to the user, it's IMPORTANT to make sure
    /// we always return AppInfo for the bundleID provided.  This ensures that the user can always remove
    /// an exclusion through the UI, even if the app has been deleted from the system.  For this purpose
    /// when the app information cannot be retrieved, this method will return AppInfor with the bundleID
    /// as the app's name.
    ///
    func getAppInfo(bundleID: String) -> AppInfo {
        appInfoRetriever.getAppInfo(bundleID: bundleID) ?? AppInfo(bundleID: bundleID, name: bundleID, icon: NSImage.window16)
    }

    func reloadVPN() {
        Task {
            // Allow some time for the change to propagate
            try await Task.sleep(interval: 0.1)

            // We need to allow some time for the setting to propagate
            // But ultimately this should actually be a user choice
            try await vpnXPCClient.command(.restartAdapter)
        }
    }
}
