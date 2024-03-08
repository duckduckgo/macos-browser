//
//  VPNAppEventsHandler.swift
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
import Common
import NetworkProtection

final class VPNAppEventsHandler {

    private let tunnelController: NetworkProtectionTunnelController

    init(tunnelController: NetworkProtectionTunnelController) {
        self.tunnelController = tunnelController
    }

    func appDidFinishLaunching() {
        let currentVersion = AppVersion.shared.versionAndBuildNumber
        let versionStore = NetworkProtectionLastVersionRunStore()
        defer {
            versionStore.lastVersionRun = currentVersion
        }

        let restartTunnel = {
            os_log(.info, log: .networkProtection, "App updated from %{public}s to %{public}s: updating login items", versionStore.lastVersionRun ?? "null", currentVersion)
            self.restartTunnel()
        }

#if DEBUG || REVIEW // Since DEBUG and REVIEW builds may not change version No. we want them to always reset.
        restartTunnel()
#else
        if versionStore.lastVersionRun != currentVersion {
            restartTunnel()
        }
#endif
    }

    // MARK: - Private code

    private func restartTunnel() {
        Task {
            // Restart NetP SysEx on app update
            if await tunnelController.isConnected {
                await tunnelController.restart()
            }
        }
    }
}
