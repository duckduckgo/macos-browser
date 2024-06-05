//
//  NetworkProtectionNotificationsPresenterFactory.swift
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

import AppLauncher
import Foundation
import NetworkProtection

/// A convenience class for making notification presenters.
///
struct NetworkProtectionNotificationsPresenterFactory {
    func make(settings: VPNSettings, defaults: UserDefaults) -> NetworkProtectionNotificationsPresenter {
        let presenterForBuildType = makePresenterForBuildType()

        return NetworkProtectionNotificationsPresenterTogglableDecorator(
            settings: settings,
            defaults: defaults,
            wrappee: presenterForBuildType)
    }

    private func makePresenterForBuildType() -> NetworkProtectionNotificationsPresenter {
    #if NETP_SYSTEM_EXTENSION
            return NetworkProtectionAgentNotificationsPresenter(notificationCenter: DistributedNotificationCenter.default())
    #else
            let parentBundlePath = "../../../"
            let mainAppURL: URL
            if #available(macOS 13, *) {
                mainAppURL = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
            } else {
                mainAppURL = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
            }
            return NetworkProtectionUNNotificationsPresenter(appLauncher: AppLauncher(appBundleURL: mainAppURL))
    #endif
    }
}
