//
//  VPNMetadataCollector.swift
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

import Foundation
import Common

struct VPNMetadata: Encodable {

    struct AppInfo: Encodable {
        let appVersion: String
        let isInternalUser: Bool
    }

    struct DeviceInfo: Encodable {
        let osVersion: String
        let buildFlavor: String
        let lowPowerModeEnabled: Bool
    }

    let appInfo: AppInfo
    let deviceInfo: DeviceInfo

    func toBase64() -> String {
        fatalError()
    }

}

struct VPNMetadataCollector {

    func collectMetadata() async -> VPNMetadata {
        let appInfoMetadata = collectAppInfoMetadata()
        let deviceInfoMetadata = collectDeviceInfoMetadata()

        return VPNMetadata(
            appInfo: appInfoMetadata,
            deviceInfo: deviceInfoMetadata
        )
    }

    // MARK: - Metadata Collection

    private func collectAppInfoMetadata() -> VPNMetadata.AppInfo {
        let appVersion = AppVersion.shared.versionAndBuildNumber
        let isInternalUser = NSApp.delegateTyped.internalUserDecider.isInternalUser

        return .init(appVersion: appVersion, isInternalUser: isInternalUser)
    }

    private func collectDeviceInfoMetadata() -> VPNMetadata.DeviceInfo {
#if APPSTORE
        let buildFlavor: String = "appstore"
#else
        let buildFlavor: String = "dmg"
#endif

        let osVersion = AppVersion.shared.osVersion
        let lowPowerModeEnabled: Bool

        if #available(macOS 12.0, *) {
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            lowPowerModeEnabled = false
        }

        return .init(osVersion: osVersion, buildFlavor: buildFlavor, lowPowerModeEnabled: lowPowerModeEnabled)
    }

    func collectNetworkInformation() async {
        print("DEBUG: Network Information")

        let monitor = NWPathMonitor()
        for await path in monitor.paths() {
            print(path.debugDescription)
        }

        print("Done!")
    }

}

extension NWPathMonitor {

    fileprivate func paths() -> AsyncStream<NWPath> {
        AsyncStream { continuation in
            pathUpdateHandler = { path in
                continuation.yield(path)
            }

            continuation.onTermination = { [weak self] _ in
                self?.cancel()
            }

            start(queue: DispatchQueue(label: "VPNMetadataCollector.NWPathMonitor.paths"))
        }
    }

}
