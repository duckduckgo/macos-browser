//
//  MacTransparentProxyProvider.swift
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

import Combine
import Common
import Foundation
import Networking
import NetworkExtension
import NetworkProtectionProxy
import os.log
import PixelKit

final class MacTransparentProxyProvider: TransparentProxyProvider {

    static var vpnProxyLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DuckDuckGo", category: "VPN Proxy")

    private var cancellables = Set<AnyCancellable>()

    @objc init() {
        let loadSettingsFromStartupOptions: Bool = {
#if NETP_SYSTEM_EXTENSION
            true
#else
            false
#endif
        }()

        let settings: TransparentProxySettings = {
#if NETP_SYSTEM_EXTENSION
            /// Because our System Extension is running in the system context and doesn't have access
            /// to shared user defaults, we just make it use the `.standard` defaults.
            TransparentProxySettings(defaults: .standard)
#else
            /// Because our App Extension is running in the user context and has access
            /// to shared user defaults, we take advantage of this and use the `.netP` defaults.
            TransparentProxySettings(defaults: .netP)
#endif
        }()

        let configuration = TransparentProxyProvider.Configuration(
            loadSettingsFromProviderConfiguration: loadSettingsFromStartupOptions)

#if !NETP_SYSTEM_EXTENSION
        let dryRun: Bool
#if DEBUG
        dryRun = true
#else
        dryRun = false
#endif

        PixelKit.setUp(dryRun: dryRun,
                       appVersion: AppVersion.shared.versionNumber,
                       source: "vpnProxyExtension",
                       defaultHeaders: [:],
                       defaults: .netP) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping PixelKit.CompletionBlock) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            let apiHeaders = APIRequest.Headers(additionalHeaders: headers)
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(error == nil, error)
            }
        }
#endif

        let eventHandler = TransparentProxyProviderEventHandler(logger: Self.vpnProxyLogger)

        super.init(settings: settings,
                   configuration: configuration,
                   logger: Self.vpnProxyLogger,
                   eventHandler: eventHandler)
    }
}
